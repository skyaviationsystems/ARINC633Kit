// RAIMReportParser.swift
// ARINC633Kit
//
// Parser for the RAIMReport message (root <RAIMReport>, RAIMReport.xsd / RAIM.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, then <GNSSReceiver>, <RAIMAirportPredictions> and
// <RAIMTrajectoryPredictions> are mapped to typed models, with any unrecognized top-level
// payload children swept into the model's `extensions` bag (nothing dropped).

import Foundation

/// Parses a `<RAIMReport>` document into a `RAIMReport`.
public final class RAIMReportParser: Sendable {

    public init() {}

    /// Parse RAIMReport XML into a typed `RAIMReport`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> RAIMReport {
        let root = try GenericElementParser().parse(data: data)

        var report = RAIMReport(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        report.creationTime = root.attribute("creationTime")
        report.fullPackage = Self.bool(root.attribute("fullPackage"))

        if let recv = root.firstDescendant(named: "GNSSReceiver") {
            report.receiver = Self.receiver(from: recv)
        }

        report.airportPredictions = (root.firstDescendant(named: "RAIMAirportPredictions")?
            .all(named: "RAIMAirportPrediction") ?? []).map(Self.airportPrediction)

        report.trajectoryPredictions = (root.firstDescendant(named: "RAIMTrajectoryPredictions")?
            .all(named: "RAIMTrajectoryPrediction") ?? []).map(Self.trajectoryPrediction)

        // Preserve any unmodeled top-level payload children.
        let mapped: Set<String> = ["GNSSReceiver", "RAIMAirportPredictions", "RAIMTrajectoryPredictions"]
        report.extensions = root.payloadChildren.filter { !mapped.contains($0.name) }
        return report
    }

    // MARK: - GNSSReceiver

    private static func receiver(from el: CapturedElement) -> GNSSReceiver {
        GNSSReceiver(
            type: el.attribute("type"),
            algorithm: el.attribute("algorithm"),
            selectiveAvailability: bool(el.attribute("sa")),
            baroAiding: bool(el.attribute("baroAiding")),
            maskAngle: el.attribute("maskAngle").flatMap(Double.init)
        )
    }

    // MARK: - Airport predictions

    private static func airportPrediction(from el: CapturedElement) -> RAIMAirportPrediction {
        var p = RAIMAirportPrediction()
        let airport = el.first(named: "Airport")
        p.airportICAO = airport?.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil
        p.airportIATA = airport?.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
        p.airportName = airport?.attribute("airportName")

        // <Elevation> is an AltitudeType <Value unit="...">; samples use unit "ft".
        if let vu = el.first(named: "Elevation")?.valueAndUnit() {
            p.elevation = ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft")
        }
        p.coordinates = coordinates(from: el.first(named: "Coordinates"))
        p.timeRange = timeRange(from: el.first(named: "TimeRangeParameters"))
        p.parameters = parameters(from: el.first(named: "RAIMParameters"))
        p.outages = (el.first(named: "RAIMOutages")?.all(named: "RAIMOutage") ?? []).map(raimOutage)
        p.satelliteInformation = satelliteInformation(from: el.first(named: "SatelliteInformations"))
        p.remark = el.first(named: "Remark")?.text.trimmedOrNil
        p.outageReported = bool(el.attribute("outageReported"))
        p.airportFunction = el.attribute("airportFunction")
        return p
    }

    // MARK: - Trajectory predictions

    private static func trajectoryPrediction(from el: CapturedElement) -> RAIMTrajectoryPrediction {
        var t = RAIMTrajectoryPrediction()
        if let adsb = el.first(named: "ADSBParameters") {
            t.adsbParameters = ADSBParameters(
                minNic: adsb.attribute("minNic").flatMap(Int.init),
                minNacp: adsb.attribute("minNacp").flatMap(Int.init),
                integrityLevel: adsb.attribute("integrityLevel"),
                minimumOutage: adsb.attribute("minimumOutage")
            )
        }
        t.etoScenarios = (el.first(named: "ETOScenarios")?.all(named: "ETOScenario") ?? []).map(etoScenario)
        t.satelliteInformation = satelliteInformation(from: el.first(named: "SatelliteInformations"))
        t.remark = el.first(named: "Remark")?.text.trimmedOrNil
        t.outageReported = bool(el.attribute("outageReported"))
        t.airportFunction = el.attribute("airportFunction")
        return t
    }

    private static func etoScenario(from el: CapturedElement) -> RAIMETOScenario {
        RAIMETOScenario(
            timeScenarioOffset: el.attribute("timeScenarioOffset"),
            waypoints: el.all(named: "Waypoint").map(waypoint)
        )
    }

    private static func waypoint(from el: CapturedElement) -> RAIMWaypoint {
        var w = RAIMWaypoint()
        w.waypointId = el.attribute("waypointId")
        w.waypointName = el.attribute("waypointName")
        w.countryICAOCode = el.attribute("countryICAOCode")
        w.waypointLongName = el.attribute("waypointLongName")
        w.coordinates = coordinates(from: el.first(named: "Coordinates"))
        if let airway = el.first(named: "Airway") {
            w.airway = airway.text.trimmedOrNil
            w.airwayType = airway.attribute("type")
        }
        w.timeOverWaypoint = el.first(named: "TimeOverWaypoint")?.text.trimmedOrNil
        if let vu = el.first(named: "Altitude")?.valueAndUnit() {
            w.altitude = ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft")
        }
        w.parameters = parameters(from: el.first(named: "RAIMParameters"))
        w.raimOutages = (el.first(named: "RAIMOutages")?.all(named: "RAIMOutage") ?? []).map(raimOutage)
        w.adsbOutages = (el.first(named: "ADSBOutages")?.all(named: "ADSBOutage") ?? []).map(adsbOutage)
        return w
    }

    // MARK: - Shared mappers

    private static func coordinates(from el: CapturedElement?) -> RAIMCoordinates? {
        guard let el else { return nil }
        return RAIMCoordinates(
            latitude: el.attribute("latitude").flatMap(Double.init),
            longitude: el.attribute("longitude").flatMap(Double.init),
            magneticVariation: el.attribute("magneticVariation").flatMap(Double.init)
        )
    }

    private static func timeRange(from el: CapturedElement?) -> RAIMTimeRange? {
        guard let el else { return nil }
        return RAIMTimeRange(
            begin: el.attribute("begin"),
            samplePeriod: el.attribute("samplePeriod"),
            end: el.attribute("end")
        )
    }

    private static func parameters(from el: CapturedElement?) -> RAIMParameters? {
        guard let el else { return nil }
        return RAIMParameters(
            rnpValue: el.attribute("rnpValue").flatMap(Double.init),
            integrityLevel: el.attribute("integrityLevel"),
            minimumOutage: el.attribute("minimumOutage"),
            maskAngle: el.attribute("maskAngle").flatMap(Double.init)
        )
    }

    private static func raimOutage(from el: CapturedElement) -> RAIMOutage {
        RAIMOutage(
            beginOfOutage: el.attribute("beginOfOutage"),
            endOfOutage: el.attribute("endOfOutage"),
            worstHPL: el.attribute("worstHPL").flatMap(Double.init),
            numberOfSatellites: el.attribute("numberOfSatellites").flatMap(Int.init)
        )
    }

    private static func adsbOutage(from el: CapturedElement) -> ADSBOutage {
        ADSBOutage(
            beginOfOutage: el.attribute("beginOfOutage"),
            endOfOutage: el.attribute("endOfOutage"),
            numberOfSatellites: el.attribute("numberOfSatellites").flatMap(Int.init),
            worstNic: el.attribute("worstNic").flatMap(Int.init),
            worstNacp: el.attribute("worstNacp").flatMap(Int.init),
            worstHfom: el.attribute("worstHfom").flatMap(Double.init)
        )
    }

    private static func satelliteInformation(from el: CapturedElement?) -> [SatelliteInformation] {
        (el?.all(named: "SatelliteInformation") ?? []).map {
            SatelliteInformation(
                gnss: $0.attribute("GNSS"),
                almanac: $0.attribute("almanac"),
                nanus: $0.attribute("nanus")
            )
        }
    }

    private static func bool(_ s: String?) -> Bool? {
        s.map { $0 == "true" || $0 == "1" }
    }
}
