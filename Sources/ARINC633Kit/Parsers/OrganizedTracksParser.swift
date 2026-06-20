// OrganizedTracksParser.swift
// ARINC633Kit
//
// Parser for the Organized Track System message (root <OrganizedTracks>,
// OrganizedTracks.xsd / RouteDefinition.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted
// via CapturedElement helpers, then each track (a RouteDefinitionType) is mapped to a
// typed RouteDefinition, recursing through connection segments. Unrecognized top-level
// children are swept into the model's `extensions` bag so nothing is dropped.
//
// Both the schema element names and the names seen in published samples are accepted:
//   tracks:       <OrganizedTracksSet>/<OrganizedTrack>  or  <OrganizedTrack> at root
//   waypoints:    <RouteWaypoints>/<RouteWaypoint>       or  <Waypoints>/<Waypoint>
//   connections:  <EntryConnections>/<ExitConnections>   or  <Connections> (+@entryExit)

import Foundation

/// Parses an `<OrganizedTracks>` document into an `OrganizedTracksMessage`.
public final class OrganizedTracksParser: Sendable {

    public init() {}

    /// Parse Organized Tracks XML into a typed `OrganizedTracksMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> OrganizedTracksMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = OrganizedTracksMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            trackMessageIdentifier: root.attribute("trackMessageIdentifier"),
            area: root.attribute("area")
        )

        // Tracks: prefer the schema wrapper, fall back to tracks directly under root.
        let trackContainer = root.first(named: "OrganizedTracksSet") ?? root
        for trackEl in trackContainer.all(named: "OrganizedTrack") {
            message.tracks.append(Self.route(from: trackEl, entryExit: nil))
        }

        // Top-level remarks.
        if let remarks = root.first(named: "Remarks") {
            message.remarks = remarks.all(named: "Remark").map(Self.remarkText)
        }

        // Original publication source (NOTAM reference / free text / foreign content).
        message.organizedTrackMessage = root.first(named: "OrganizedTrackMessage")

        // Preserve any unmodeled top-level payload children.
        let mapped: Set<String> = ["OrganizedTracksSet", "OrganizedTrack", "Remarks", "OrganizedTrackMessage"]
        message.extensions = root.payloadChildren.filter { !mapped.contains($0.name) }
        return message
    }

    // MARK: - Route (RouteDefinitionType)

    private static func route(from el: CapturedElement, entryExit: String?) -> RouteDefinition {
        var r = RouteDefinition()
        r.routeIdentifier = el.attribute("routeIdentifier")
        r.revisionTime = el.attribute("revisionTime")
        r.area = el.attribute("area")
        r.startValidTime = el.attribute("startValidTime")
        r.endValidTime = el.attribute("endValidTime")
        r.trackApplicability = el.attribute("trackApplicability")
        // Sample encoding tags a connection's role with @entryExit; otherwise the role
        // is implied by the wrapping EntryConnections/ExitConnections element.
        r.entryExit = el.attribute("entryExit") ?? entryExit

        // Lateral route waypoints (schema or sample container names).
        if let lateral = el.first(named: "LateralRoute") {
            let wpContainer = lateral.first(named: "RouteWaypoints") ?? lateral.first(named: "Waypoints")
            let wpEls = (wpContainer?.all(named: "RouteWaypoint") ?? []) + (wpContainer?.all(named: "Waypoint") ?? [])
            r.waypoints = wpEls.map(Self.waypoint)
        }

        // Vertical route altitude groups.
        if let vertical = el.first(named: "VerticalRoute") {
            r.altitudeGroups = vertical.all(named: "Altitudes").map(Self.altitudeGroup)
        }

        // Valid airports.
        if let airports = el.first(named: "Airports") {
            r.airports = airports.all(named: "Airport").map(Self.airport)
        }

        // Connections (recursive). Schema splits entry/exit; sample uses one container.
        r.connections = []
        for c in (el.first(named: "EntryConnections")?.all(named: "Connection") ?? []) {
            r.connections.append(Self.route(from: c, entryExit: "entry"))
        }
        for c in (el.first(named: "ExitConnections")?.all(named: "Connection") ?? []) {
            r.connections.append(Self.route(from: c, entryExit: "exit"))
        }
        for c in (el.first(named: "Connections")?.all(named: "Connection") ?? []) {
            r.connections.append(Self.route(from: c, entryExit: nil))
        }

        // Route-level remarks.
        if let remarks = el.first(named: "Remarks") {
            r.remarks = remarks.all(named: "Remark").map(Self.remarkText)
        }
        return r
    }

    // MARK: - Waypoint

    private static func waypoint(from el: CapturedElement) -> RouteWaypoint {
        var w = RouteWaypoint()
        w.sequenceId = el.attribute("sequenceId").flatMap { Int($0) }
        w.waypointId = el.attribute("waypointId")
        w.waypointName = el.attribute("waypointName")
        w.waypointLongName = el.attribute("waypointLongName")
        w.countryICAOCode = el.attribute("countryICAOCode")

        if let coords = el.first(named: "Coordinates") {
            if let latStr = coords.attribute("latitude"), let lonStr = coords.attribute("longitude"),
               let lat = Double(latStr), let lon = Double(lonStr) {
                w.coordinate = ARINCCoordinate(latitudeArcSeconds: lat, longitudeArcSeconds: lon)
            }
            w.coordinatesText = coords.text.trimmedOrNil
        }

        if let airway = el.first(named: "Airway") {
            w.airway = airway.text.trimmedOrNil
            w.airwayType = airway.attribute("type")
        }

        // Functions: schema wraps them in <Functions>; samples repeat <Function> directly.
        var functions: [String] = []
        if let container = el.first(named: "Functions") {
            functions.append(contentsOf: container.all(named: "Function").compactMap { $0.text.trimmedOrNil })
        }
        functions.append(contentsOf: el.all(named: "Function").compactMap { $0.text.trimmedOrNil })
        w.functions = functions
        return w
    }

    // MARK: - Altitudes / Airports / Remarks

    private static func altitudeGroup(from el: CapturedElement) -> AltitudeGroup {
        var g = AltitudeGroup(direction: el.attribute("direction"))
        g.altitudes = el.all(named: "Altitude").compactMap { altEl in
            guard let vu = altEl.valueAndUnit() else { return nil }
            return ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft/100")
        }
        return g
    }

    private static func airport(from el: CapturedElement) -> RouteAirport {
        RouteAirport(
            icaoCode: el.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil,
            iataCode: el.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
        )
    }

    /// Render a `<Remark>` (TextType) as text, joining `<Paragraph>/<Text>` by newline.
    private static func remarkText(from el: CapturedElement) -> String {
        var out: [String] = []
        func walk(_ node: CapturedElement) {
            if node.name == "Text", let t = node.text.trimmedOrNil { out.append(t) }
            node.children.forEach(walk)
        }
        walk(el)
        return out.isEmpty ? el.text.trimmingCharacters(in: .whitespacesAndNewlines)
                           : out.joined(separator: "\n")
    }
}
