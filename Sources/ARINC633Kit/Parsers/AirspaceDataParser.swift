// AirspaceDataParser.swift
// ARINC633Kit
//
// Parser for the AirspaceData message (root <AirspaceData>, AirspaceData.xsd).
//
// Tree-walk over the captured document: the envelope is extracted via CapturedElement
// helpers, then each <Airspace> is mapped to a typed model. Border points, distances,
// charges and overflight-permit information are mapped where present; any unrecognized
// children are swept into per-level `extensions` bags so nothing is dropped.

import Foundation

/// Parses an `<AirspaceData>` document into an `AirspaceDataMessage`.
public final class AirspaceDataParser: Sendable {

    public init() {}

    /// Parse AirspaceData XML into a typed `AirspaceDataMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> AirspaceDataMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = AirspaceDataMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )
        message.flightPlanId = root.firstDescendant(named: "AirspaceData")?.attribute("flightPlanId")
            ?? root.attribute("flightPlanId")

        for airspaceEl in root.payloadChildren where airspaceEl.name == "Airspace" {
            message.airspaces.append(Self.airspace(from: airspaceEl))
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { $0.name != "Airspace" }
        return message
    }

    // MARK: - Airspace

    private static func airspace(from el: CapturedElement) -> Airspace {
        var a = Airspace()
        a.airspaceICAOCode = el.attribute("airspaceICAOCode")
        a.airspaceName = el.attribute("airspaceName")
        a.airspaceType = el.attribute("airspaceType")
        a.sequence = el.attribute("sequence")

        a.entry = el.first(named: "Entry").map(Self.borderPoint)
        a.exit = el.first(named: "Exit").map(Self.borderPoint)
        a.greatCircleDistance = el.first(named: "GreatCircleDistance").flatMap(Self.distance)
        a.groundDistance = el.first(named: "GroundDistance").flatMap(Self.distance)

        if let charges = el.first(named: "EnrouteChargesInformation") {
            a.enrouteCharges = EnrouteChargesInformation(
                distanceMethod: charges.attribute("distanceMethod"),
                localCurrency: charges.attribute("localCurrency"),
                amountInLocalCurrency: charges.attribute("amountInLocalCurrency").flatMap { Double($0) },
                unifiedCurrency: charges.attribute("unifiedCurrency"),
                amountInUnifiedCurrency: charges.attribute("amountInUnifiedCurrency").flatMap { Double($0) }
            )
        }
        if let permit = el.first(named: "OverflightPermitInformation") {
            a.overflightPermit = OverflightPermitInformation(
                permitId: permit.attribute("permitId"),
                isPermitRequired: permit.attribute("isPermitRequired").map { $0 == "true" || $0 == "1" }
            )
        }

        let known: Set<String> = [
            "Entry", "Exit", "GreatCircleDistance", "GroundDistance",
            "EnrouteChargesInformation", "OverflightPermitInformation"
        ]
        a.extensions = el.children.filter { !known.contains($0.name) }
        return a
    }

    // MARK: - Border point

    private static func borderPoint(from el: CapturedElement) -> AirspaceBorderPoint {
        var p = AirspaceBorderPoint()
        p.coordinates = el.first(named: "Coordinates").flatMap(Self.coordinate)
        p.cumulatedGroundDistance = el.first(named: "CumulatedGroundDistance").flatMap(Self.distance)
        p.cumulatedFlightTime = el.attribute("cumulatedFlightTime")

        if let wp = el.first(named: "NearestWaypoint") {
            p.nearestWaypoint = AirspaceWaypoint(
                waypointId: wp.attribute("waypointId"),
                waypointName: wp.attribute("waypointName"),
                countryICAOCode: wp.attribute("countryICAOCode"),
                coordinates: wp.first(named: "Coordinates").flatMap(Self.coordinate),
                function: wp.first(named: "Function")?.text.trimmedOrNil
            )
        }

        let known: Set<String> = ["Coordinates", "CumulatedGroundDistance", "NearestWaypoint"]
        p.extensions = el.children.filter { !known.contains($0.name) }
        return p
    }

    // MARK: - Leaf helpers

    /// A `<Coordinates latitude= longitude=>` element (arc-seconds) -> `ARINCCoordinate`.
    private static func coordinate(from el: CapturedElement) -> ARINCCoordinate? {
        guard let lat = el.attribute("latitude").flatMap({ Double($0) }),
              let lon = el.attribute("longitude").flatMap({ Double($0) }) else { return nil }
        return ARINCCoordinate(latitudeArcSeconds: lat, longitudeArcSeconds: lon)
    }

    /// A distance element with float text content and a `unit` attribute (default "NM").
    private static func distance(from el: CapturedElement) -> ARINCDistance? {
        guard let v = el.doubleValue else { return nil }
        return ARINCDistance(value: v, unit: el.attribute("unit") ?? "NM")
    }
}
