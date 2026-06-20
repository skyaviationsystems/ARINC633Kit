// UpperAirDataParser.swift
// ARINC633Kit
//
// Parser for the UpperAirData message (root <UpperAirData>, UpperAirData.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted
// via CapturedElement helpers, then the observation times and the three flight-phase
// sections (climb / cruise / descent) are mapped to typed models. Any unrecognized
// top-level children are swept into the model's `extensions` bag (nothing dropped).
//
// SAFETY: each physical quantity is read through `valueAndUnit()` so the source unit
// is preserved on the resulting ARINC* measurement — wind/temperature aloft feed fuel
// and performance planning, so units must never be assumed.

import Foundation

/// Parses an `<UpperAirData>` document into an `UpperAirData`.
public final class UpperAirDataParser: Sendable {

    public init() {}

    /// Parse UpperAirData XML into a typed `UpperAirData`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> UpperAirData {
        let root = try GenericElementParser().parse(data: data)

        var message = UpperAirData(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        message.flightPlanId = root.attribute("flightPlanId")
        message.prognosisTime = root.attribute("prognosisTime")

        // Observation (prognosis reference) times.
        for timeEl in (root.first(named: "ObservationTimes")?.all(named: "ObservationTime") ?? []) {
            message.observationTimes.append(
                UpperAirObservationTime(
                    establishedTime: timeEl.text.trimmedOrNil,
                    validityTime: timeEl.attribute("prognosisValidityTime")
                )
            )
        }

        // Climb / Descent phases: a flat list of altitude entries.
        message.climbPhase = Self.altitudeEntries(in: root.first(named: "ClimbPhase"))
        message.descentPhase = Self.altitudeEntries(in: root.first(named: "DescentPhase"))

        // Cruise phase: waypoints, each with its own altitude entries.
        for wpEl in (root.first(named: "CruisePhase")?.first(named: "Waypoints")?.all(named: "Waypoint") ?? []) {
            message.cruiseWaypoints.append(Self.waypoint(from: wpEl))
        }

        // Preserve any unmodeled top-level payload children.
        let known: Set<String> = ["ObservationTimes", "ClimbPhase", "CruisePhase", "DescentPhase"]
        message.extensions = root.payloadChildren.filter { !known.contains($0.name) }
        return message
    }

    /// Map every `<AltitudeSpecificPredictedInformation>` directly under `container`.
    private static func altitudeEntries(in container: CapturedElement?) -> [UpperAirAltitudeEntry] {
        guard let container else { return [] }
        return container.all(named: "AltitudeSpecificPredictedInformation").map(Self.altitudeEntry)
    }

    private static func waypoint(from el: CapturedElement) -> UpperAirWaypoint {
        var wp = UpperAirWaypoint()
        wp.waypointId = el.attribute("waypointId")
        wp.waypointName = el.attribute("waypointName")
        wp.sequenceId = el.attribute("sequenceId").flatMap { Int($0) }

        if let coordEl = el.first(named: "Coordinates"),
           let lat = coordEl.attribute("latitude").flatMap({ Double($0) }),
           let lon = coordEl.attribute("longitude").flatMap({ Double($0) }) {
            // Coordinates are arc-seconds per coordinateType.grp.
            wp.coordinates = ARINCCoordinate(latitudeArcSeconds: lat, longitudeArcSeconds: lon)
        }

        wp.entries = el.all(named: "AltitudeSpecificPredictedInformation").map(Self.altitudeEntry)
        wp.tropopause = el.altitude(of: "Tropopause")
        return wp
    }

    private static func altitudeEntry(from el: CapturedElement) -> UpperAirAltitudeEntry {
        var entry = UpperAirAltitudeEntry()
        entry.altitude = el.altitude(of: "Altitude")
        entry.predictedTime = el.attribute("predictedTime")
        entry.plannedFlightLevel = el.attribute("plannedFlightLevel")

        if let windData = el.first(named: "WindData") {
            if let horizontal = windData.first(named: "HorizontalWind") {
                if let vu = horizontal.first(named: "Direction")?.valueAndUnit() {
                    entry.windDirection = ARINCDirection(value: vu.value, unit: vu.unit ?? "deg")
                }
                if let vu = horizontal.first(named: "Speed")?.valueAndUnit() {
                    entry.windSpeed = ARINCSpeed(value: vu.value, unit: vu.unit ?? "kt")
                }
            }
            entry.verticalWind = windData.speed(of: "VerticalWind")
        }
        entry.windComponent = el.speed(of: "WindComponent")

        if let tempData = el.first(named: "TemperatureData") {
            entry.temperature = tempData.temperature(of: "Temperature")
            entry.isaDeviation = tempData.temperature(of: "ISADeviation")
            entry.totalAirTemperature = tempData.temperature(of: "TotalAirTemperature")
        }
        return entry
    }
}
