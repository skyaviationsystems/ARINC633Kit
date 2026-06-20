// AirportDataParser.swift
// ARINC633Kit
//
// Parser for the CommonData AirportData message (root <AirportData>, AirportData.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, then each repeated <Airport> description is mapped to a typed
// AirportDescription, with unrecognized children swept into `extensions` bags so nothing
// is dropped.
//
// NOTE: In this schema, physical quantities such as <Elevation>, <LandingDistanceAvailable>
// and <QFU> use *simple content* — the numeric text lives on the element with the unit on
// an attribute (e.g. <Elevation unit="m">39.624</Elevation>) — rather than the
// <Value unit="...">N</Value> wrapper used elsewhere. The helpers below read text+@unit
// directly. <Coordinates> carry latitude/longitude in arc-seconds (coordinateType.grp).

import Foundation

/// Parses an `<AirportData>` document into an `AirportDataMessage`.
public final class AirportDataParser: Sendable {

    public init() {}

    /// Parse AirportData XML into a typed `AirportDataMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> AirportDataMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = AirportDataMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        message.flightPlanId = root.attribute("flightPlanId")
        message.creationTime = root.attribute("creationTime")
        message.fullPackage = root.attribute("fullPackage").map(Self.bool)

        // The legacy/sample payload repeats <Airport> directly under the root; the active
        // schema wraps them in <AirportDescriptions>/<AirportDescription>. Support both.
        var airportEls = root.all(named: "Airport")
        if airportEls.isEmpty, let descs = root.first(named: "AirportDescriptions") {
            airportEls = descs.all(named: "AirportDescription")
        }
        for airportEl in airportEls {
            message.airports.append(Self.airport(from: airportEl))
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter {
            $0.name != "Airport" && $0.name != "AirportDescriptions"
        }
        return message
    }

    // MARK: - Airport

    private static func airport(from el: CapturedElement) -> AirportDescription {
        var a = AirportDescription()

        // An <AirportDescription> wraps the identification in a nested <Airport>; the
        // legacy <Airport> form uses <AirportIdentification>. Resolve whichever applies.
        let ident = el.first(named: "AirportIdentification") ?? el.first(named: "Airport") ?? el
        a.airportICAO = ident.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil
        a.airportIATA = ident.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
        a.airportName = ident.attribute("airportName") ?? el.attribute("airportName")
        a.sequence = el.attribute("sequence")

        // Runways: present either directly as repeated <Runway> children (sample form) or
        // wrapped in a <Runways> container (active schema form).
        var runwayEls = el.all(named: "Runway")
        if runwayEls.isEmpty, let runways = el.first(named: "Runways") {
            runwayEls = runways.all(named: "Runway")
        }
        a.runways = runwayEls.map(Self.runway)

        // Terminal procedures: each <TerminalProcedures> is one procedure (sample form);
        // the active schema nests <AirportTerminalProcedure> inside a <TerminalProcedures> wrapper.
        for procEl in el.all(named: "TerminalProcedures") {
            if procEl.first(named: "AirportTerminalProcedure") != nil {
                for inner in procEl.all(named: "AirportTerminalProcedure") {
                    a.terminalProcedures.append(Self.procedure(from: inner))
                }
            } else {
                a.terminalProcedures.append(Self.procedure(from: procEl))
            }
        }

        a.magneticVariation = el.first(named: "MagneticVariation")?.doubleValue
        a.elevation = el.first(named: "Elevation").flatMap(Self.altitude)
        a.referencePoint = el.first(named: "AirportReferencePoint")
            .flatMap { $0.first(named: "Coordinates") }
            .flatMap(Self.coordinate)
        a.rescueAndFireFightingCategory = el.first(named: "RescueAndFireFightingCategory")?.intValue
        a.requiredFlightCrewQualification = el.first(named: "RequiredFlightCrewQualification")?.text.trimmedOrNil

        if let hours = el.first(named: "OpeningHours") {
            a.openingHoursFrom = hours.attribute("from")
            a.openingHoursUntil = hours.attribute("until")
        }
        if let offset = el.first(named: "LocalTimeOffsetToUTC") {
            a.localTimeOffsetToUTC = offset.text.trimmedOrNil
            a.localTimeOffsetPositive = offset.attribute("positive").map(Self.bool)
        }
        if let freqs = el.first(named: "ATISRadioFrequencies") {
            a.atisFrequencies = freqs.all(named: "ATISFrequency").compactMap { $0.doubleValue }
        }

        // Sweep unmodeled children into the airport's extensions bag.
        let known: Set<String> = [
            "AirportIdentification", "Airport", "Runway", "Runways", "TerminalProcedures",
            "MagneticVariation", "Elevation", "AirportReferencePoint",
            "RescueAndFireFightingCategory", "RequiredFlightCrewQualification",
            "OpeningHours", "LocalTimeOffsetToUTC", "ATISRadioFrequencies"
        ]
        a.extensions = el.children.filter { !known.contains($0.name) }
        return a
    }

    // MARK: - Runway

    private static func runway(from el: CapturedElement) -> AirportRunway {
        var r = AirportRunway(
            runwayIdentifier: el.attribute("runwayIdentifier")
                ?? el.text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        r.qfuMagneticTrack = el.first(named: "QFU")?.doubleValue
        r.approaches = el.all(named: "Approach").map(Self.approach)
        r.landingDistanceAvailable = el.first(named: "LandingDistanceAvailable").flatMap(Self.distance)
        r.landingThreshold = el.first(named: "LandingThreshold")
            .flatMap { $0.first(named: "Coordinates") }
            .flatMap(Self.coordinate)
        r.takeoffDistanceAvailable = el.first(named: "TakeoffDistanceAvailable").flatMap(Self.distance)
        r.takeoffRunAvailable = el.first(named: "TakeoffRunAvailable").flatMap(Self.distance)
        r.elevation = el.first(named: "Elevation").flatMap(Self.altitude)
        r.slope = el.first(named: "Slope")?.doubleValue
        r.approvedForRegularOperation = el.first(named: "ApprovedForRegularOperation").map { Self.bool($0.text) }
        return r
    }

    private static func approach(from el: CapturedElement) -> RunwayApproach {
        var ap = RunwayApproach(
            procedureName: el.attribute("procedureName"),
            fmsProcedureName: el.attribute("fMSProcedureName"),
            category: el.attribute("category"),
            precisionApproach: el.attribute("precisionApproach").map(Self.bool)
        )
        ap.requiredHorizontalVisibility = el.first(named: "RequiredHorizontalVisibility").flatMap(Self.distance)
        ap.requiredVerticalVisibility = el.first(named: "RequiredVerticalVisibility").flatMap(Self.distance)
        return ap
    }

    // MARK: - Terminal procedure

    private static func procedure(from el: CapturedElement) -> AirportTerminalProcedure {
        var p = AirportTerminalProcedure(
            procedureName: el.attribute("procedureName"),
            fmsProcedureName: el.attribute("fMSProcedureName"),
            procedureType: el.attribute("procedureType")
        )
        p.waypoints = el.all(named: "Waypoint").map(Self.waypoint)
        return p
    }

    private static func waypoint(from el: CapturedElement) -> ProcedureWaypoint {
        var w = ProcedureWaypoint(
            waypointId: el.attribute("waypointId"),
            waypointName: el.attribute("waypointName"),
            sequenceId: el.attribute("sequenceId").flatMap { Int($0) }
        )
        w.coordinates = el.first(named: "Coordinates").flatMap(Self.coordinate)
        if let airway = el.first(named: "Airway") {
            w.airway = airway.text.trimmedOrNil
            w.airwayType = airway.attribute("type")
        }
        return w
    }

    // MARK: - Value helpers

    /// Parse a `<Coordinates latitude="..." longitude="..."/>` element. Both attributes are
    /// in arc-seconds per `coordinateType.grp`; convert to decimal degrees.
    private static func coordinate(from el: CapturedElement) -> ARINCCoordinate? {
        guard let lat = el.attribute("latitude").flatMap({ Double($0) }),
              let lon = el.attribute("longitude").flatMap({ Double($0) }) else { return nil }
        return ARINCCoordinate(latitudeArcSeconds: lat, longitudeArcSeconds: lon)
    }

    /// Parse a simple-content distance element (text value + `@unit`, default "m").
    private static func distance(from el: CapturedElement) -> ARINCDistance? {
        guard let v = el.doubleValue else { return nil }
        return ARINCDistance(value: v, unit: el.attribute("unit") ?? "m")
    }

    /// Parse a simple-content altitude/elevation element (text value + `@unit`, default "ft").
    private static func altitude(from el: CapturedElement) -> ARINCAltitude? {
        guard let v = el.doubleValue else { return nil }
        return ARINCAltitude(value: v, unit: el.attribute("unit") ?? "ft")
    }

    /// Interpret an XML boolean ("true"/"1") leniently.
    private static func bool(_ s: String) -> Bool { s == "true" || s == "1" }
}
