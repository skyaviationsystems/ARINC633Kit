// PIREPBriefingParser.swift
// ARINC633Kit
//
// Parser for the PIREPBriefing message (root <PIREPBriefing>, PIREPBriefing.xsd).
//
// Tree-walk over the captured document: the envelope is extracted via CapturedElement
// helpers, the root attributes (creationTime / fullPackage) are read directly, each
// <PIREP> is mapped to a typed model, and any unrecognized children are swept into the
// relevant `extensions` bag so nothing is dropped.

import Foundation

/// Parses a `<PIREPBriefing>` document into a `PIREPBriefing`.
public final class PIREPBriefingParser: Sendable {

    public init() {}

    /// Parse PIREPBriefing XML into a typed `PIREPBriefing`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> PIREPBriefing {
        let root = try GenericElementParser().parse(data: data)

        var message = PIREPBriefing(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            creationTime: root.attribute("creationTime"),
            fullPackage: root.attribute("fullPackage") == "true"
        )

        for pirepEl in (root.firstDescendant(named: "PIREPs")?.all(named: "PIREP") ?? []) {
            message.pireps.append(Self.pirep(from: pirepEl))
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { $0.name != "PIREPs" }
        return message
    }

    // MARK: - PIREP

    private static func pirep(from el: CapturedElement) -> PIREP {
        var p = PIREP()

        // Attributes.
        p.issuer = el.attribute("issuer")?.trimmedOrNil
        p.source = el.attribute("source")?.trimmedOrNil
        p.observationTime = el.attribute("observationTime")
        p.startValidTime = el.attribute("startValidTime")
        p.endValidTime = el.attribute("endValidTime")
        p.startApplicabilityTime = el.attribute("startApplicabilityTime")
        p.endApplicabilityTime = el.attribute("endApplicabilityTime")
        p.priority = el.attribute("priority").flatMap { Int($0) }
        p.sequence = el.attribute("sequence").flatMap { Int($0) }

        // Elements.
        if let textEl = el.first(named: "PirepText") {
            p.pirepText = joinedText(textEl)
        }
        if let locEl = el.first(named: "Location") {
            p.location = location(from: locEl)
        }
        if let altEl = el.first(named: "Altitudes") {
            p.altitudes = altitudes(from: altEl)
        }
        if let decEl = el.first(named: "DecodedInformation") {
            p.decoded = decoded(from: decEl)
        }
        p.remark = el.first(named: "Remark").flatMap(joinedText)
        p.aircraftICAOType = el.first(named: "AircraftICAOType")?.text.trimmedOrNil

        let mapped: Set<String> = [
            "PirepText", "Location", "Altitudes", "DecodedInformation",
            "Remark", "AircraftICAOType"
        ]
        p.extensions = el.children.filter { !mapped.contains($0.name) }
        return p
    }

    // MARK: - Location

    private static func location(from el: CapturedElement) -> PIREPLocation {
        var loc = PIREPLocation()
        loc.airspaces = (el.first(named: "Airspaces")?.all(named: "Airspace") ?? []).map { aEl in
            PIREPAirspace(icaoCode: aEl.attribute("airspaceICAOCode")?.trimmedOrNil,
                          name: aEl.first(named: "AirspaceName")?.text.trimmedOrNil)
        }
        if let geoEl = el.first(named: "Geography") {
            loc.geography = geography(from: geoEl)
        }
        if let apEl = el.first(named: "Airport") {
            var ap = PIREPAirport()
            ap.icaoCode = apEl.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil
            ap.iataCode = apEl.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
            ap.runways = (apEl.first(named: "Runways")?.all(named: "Runway") ?? [])
                .compactMap { $0.attribute("runwayIdentifier")?.trimmedOrNil }
            loc.airport = ap
        }
        return loc
    }

    private static func geography(from el: CapturedElement) -> PIREPGeography {
        var geo = PIREPGeography()
        if let spotEl = el.first(named: "Spot") {
            var spot = PIREPSpot()
            if let coordEl = spotEl.first(named: "Coordinates") {
                let latStr = coordEl.attribute("latitude")
                let lonStr = coordEl.attribute("longitude")
                spot.latitudeArcSeconds = latStr
                spot.longitudeArcSeconds = lonStr
                if let lat = latStr.flatMap({ Double($0) }),
                   let lon = lonStr.flatMap({ Double($0) }) {
                    spot.coordinate = ARINCCoordinate(latitudeArcSeconds: lat,
                                                      longitudeArcSeconds: lon)
                }
            }
            spot.radius = spotEl.distance(of: "Radius")
            geo.spot = spot
        }
        geo.extensions = el.children.filter { $0.name != "Spot" }
        return geo
    }

    // MARK: - Altitudes

    private static func altitudes(from el: CapturedElement) -> PIREPAltitudes {
        var alt = PIREPAltitudes()
        alt.altitudes = el.all(named: "Altitude").compactMap { aEl -> ARINCAltitude? in
            guard let vu = aEl.valueAndUnit() else { return nil }
            return ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft/100")
        }
        alt.upper = el.altitude(of: "Upper")
        alt.lower = el.altitude(of: "Lower")
        return alt
    }

    // MARK: - DecodedInformation

    private static func decoded(from el: CapturedElement) -> PIREPDecodedInformation {
        var d = PIREPDecodedInformation()

        if let icingEl = el.first(named: "Icing") {
            var ic = PIREPIcing()
            ic.icingType = icingEl.attribute("icingType")?.trimmedOrNil
            ic.intensity = icingEl.attribute("intensity")?.trimmedOrNil
            ic.indicatedAirSpeed = icingEl.speed(of: "IndicatedAirSpeed")
            if let temps = icingEl.first(named: "Temperatures") {
                ic.staticAirTemperature = temps.temperature(of: "StaticAirTemperature")
                ic.totalAirTemperature = temps.temperature(of: "TotalAirTemperature")
            }
            d.icing = ic
        }

        if let turbEl = el.first(named: "Turbulence") {
            var t = PIREPTurbulence()
            t.turbulenceType = turbEl.attribute("turbulenceType")?.trimmedOrNil
            t.intensity = turbEl.attribute("intensity")?.trimmedOrNil
            t.inOrNearClouds = turbEl.attribute("inOrNearClounds").map { $0 == "true" || $0 == "1" }
            t.duration = turbEl.first(named: "Duration")?.text.trimmedOrNil
            d.turbulence = t
        }

        d.thunderstormTrend = el.first(named: "Thunderstorm")?
            .first(named: "Trend")?.text.trimmedOrNil
        d.spotTemperature = el.temperature(of: "SpotTemperature")

        if let windEl = el.first(named: "SpotWind") {
            var w = PIREPWind()
            if let vu = windEl.first(named: "Direction")?.valueAndUnit() {
                w.direction = ARINCDirection(value: vu.value, unit: vu.unit ?? "deg")
            }
            w.speed = windEl.speed(of: "Speed")
            d.spotWind = w
        }

        d.windShearIntensity = el.first(named: "WindShear")?.attribute("intensity")?.trimmedOrNil
        d.microburst = el.first(named: "Microburst")
            .flatMap { $0.text.trimmedOrNil }
            .map { $0 == "true" || $0 == "1" }
        d.brakingAction = el.first(named: "BrakingAction")?.text.trimmedOrNil

        return d
    }

    // MARK: - Helpers

    /// Join all `<Text>` descendants (handles `<Paragraph><Text>` wrappers); falls
    /// back to the element's own text when no `<Text>` children are present.
    private static func joinedText(_ el: CapturedElement) -> String? {
        var out: [String] = []
        func walk(_ node: CapturedElement) {
            if node.name == "Text", let t = node.text.trimmedOrNil { out.append(t) }
            node.children.forEach(walk)
        }
        walk(el)
        return out.isEmpty ? el.text.trimmedOrNil : out.joined(separator: "\n")
    }
}
