// RegionWeatherParser.swift
// ARINC633Kit
//
// Parser for the RegionWeatherBriefing message (roots <RegionWeatherBriefing> and
// <RegionWeather>, RegionWeatherBriefing.xsd / RegionWeather.xsd).
//
// Tree-walk over the captured document: the envelope is extracted via CapturedElement
// helpers, the root attributes (creationTime / fullPackage) are read directly, each
// <RegionWeather> bulletin is mapped to a typed model, and any unrecognized children
// are swept into the relevant `extensions` bag so nothing is dropped.
//
// Two roots are supported: a full <RegionWeatherBriefing> wrapping <RegionWeathers>,
// or a bare <RegionWeather> element (resolved as a single-bulletin briefing).

import Foundation

/// Parses a `<RegionWeatherBriefing>` (or bare `<RegionWeather>`) document into a
/// `RegionWeatherBriefing`.
public final class RegionWeatherParser: Sendable {

    public init() {}

    /// Parse RegionWeather XML into a typed `RegionWeatherBriefing`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> RegionWeatherBriefing {
        let root = try GenericElementParser().parse(data: data)

        var message = RegionWeatherBriefing(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            creationTime: root.attribute("creationTime"),
            fullPackage: root.attribute("fullPackage") == "true"
        )

        if let listEl = root.firstDescendant(named: "RegionWeathers") {
            // Full briefing: a list of bulletins.
            for el in listEl.all(named: "RegionWeather") {
                message.regions.append(Self.region(from: el))
            }
            message.extensions = root.payloadChildren.filter { $0.name != "RegionWeathers" }
        } else if root.name == "RegionWeather" {
            // Bare <RegionWeather> root: treat the document itself as one bulletin.
            message.regions.append(Self.region(from: root))
        } else {
            // Unexpected shape: preserve all payload children.
            message.extensions = root.payloadChildren
        }

        return message
    }

    // MARK: - RegionWeather bulletin

    private static func region(from el: CapturedElement) -> RegionWeather {
        var r = RegionWeather()

        // Attributes.
        r.issuer = el.attribute("issuer")?.trimmedOrNil
        r.source = el.attribute("source")?.trimmedOrNil
        r.type = el.attribute("type")?.trimmedOrNil
        r.startValidTime = el.attribute("startValidTime")
        r.endValidTime = el.attribute("endValidTime")
        r.observationTime = el.attribute("observationTime")
        r.startApplicabilityTime = el.attribute("startApplicabilityTime")
        r.endApplicabilityTime = el.attribute("endApplicabilityTime")
        r.priority = el.attribute("priority").flatMap { Int($0) }
        r.sequence = el.attribute("sequence").flatMap { Int($0) }

        // Elements.
        if let textEl = el.first(named: "RegionWeatherText") {
            r.text = joinedText(textEl)
        }
        if let locEl = el.first(named: "Location") {
            r.location = location(from: locEl)
        }
        if let altEl = el.first(named: "Altitudes") {
            r.altitudes = altitudes(from: altEl)
        }
        if let decEl = el.first(named: "DecodedInformation") {
            r.decoded = decoded(from: decEl)
        }
        r.remark = el.first(named: "Remark").flatMap(joinedText)

        let mapped: Set<String> = [
            "RegionWeatherText", "Location", "Altitudes", "DecodedInformation", "Remark"
        ]
        r.extensions = el.children.filter { !mapped.contains($0.name) }
        return r
    }

    // MARK: - Location

    private static func location(from el: CapturedElement) -> RegionWeatherLocation {
        var loc = RegionWeatherLocation()
        loc.airspaces = (el.first(named: "Airspaces")?.all(named: "Airspace") ?? []).map { aEl in
            RegionWeatherAirspace(icaoCode: aEl.attribute("airspaceICAOCode")?.trimmedOrNil,
                                  name: aEl.first(named: "AirspaceName")?.text.trimmedOrNil)
        }
        if let geoEl = el.first(named: "Geography") {
            loc.geography = geography(from: geoEl)
        }
        return loc
    }

    private static func geography(from el: CapturedElement) -> RegionWeatherGeography {
        var geo = RegionWeatherGeography()

        if let polyEl = el.first(named: "Polygon") {
            var poly = RegionWeatherPolygon()
            poly.coordinates = polyEl.all(named: "Coordinates").map { coordinate(from: $0) }
            poly.borderMargin = polyEl.distance(of: "BorderMargin")
            geo.polygon = poly
        }

        if let spotEl = el.first(named: "Spot") {
            var spot = RegionWeatherSpot()
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

        geo.movementSpeed = el.speed(of: "MovementSpeed")
        if let vu = el.first(named: "MovementDirection")?.valueAndUnit() {
            geo.movementDirection = ARINCDirection(value: vu.value, unit: vu.unit ?? "deg")
        }

        geo.extensions = el.children.filter {
            !["Polygon", "Spot", "MovementSpeed", "MovementDirection"].contains($0.name)
        }
        return geo
    }

    private static func coordinate(from el: CapturedElement) -> RegionWeatherCoordinate {
        var c = RegionWeatherCoordinate()
        c.sequence = el.attribute("sequence").flatMap { Int($0) }
        let latStr = el.attribute("latitude")
        let lonStr = el.attribute("longitude")
        c.latitudeArcSeconds = latStr
        c.longitudeArcSeconds = lonStr
        if let lat = latStr.flatMap({ Double($0) }),
           let lon = lonStr.flatMap({ Double($0) }) {
            c.coordinate = ARINCCoordinate(latitudeArcSeconds: lat, longitudeArcSeconds: lon)
        }
        return c
    }

    // MARK: - Altitudes

    private static func altitudes(from el: CapturedElement) -> RegionWeatherAltitudes {
        var alt = RegionWeatherAltitudes()
        alt.altitudes = el.all(named: "Altitude").compactMap { aEl -> ARINCAltitude? in
            guard let vu = aEl.valueAndUnit() else { return nil }
            return ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft/100")
        }
        alt.upper = el.altitude(of: "Upper")
        alt.lower = el.altitude(of: "Lower")
        return alt
    }

    // MARK: - DecodedInformation

    private static func decoded(from el: CapturedElement) -> RegionWeatherDecodedInformation {
        var d = RegionWeatherDecodedInformation()

        if let icingEl = el.first(named: "Icing") {
            d.icing = RegionWeatherIcing(
                intensity: icingEl.attribute("intensity")?.trimmedOrNil,
                icingType: icingEl.attribute("icingType")?.trimmedOrNil
            )
        }

        if let turbEl = el.first(named: "Turbulence") {
            d.turbulence = RegionWeatherTurbulence(
                turbulenceType: turbEl.attribute("turbulenceType")?.trimmedOrNil,
                edr: turbEl.attribute("edr").flatMap { Double($0) },
                intensity: turbEl.attribute("intensity")?.trimmedOrNil
            )
        }

        d.thunderstormTrend = el.first(named: "Thunderstorm")?
            .first(named: "Trend")?.text.trimmedOrNil

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
