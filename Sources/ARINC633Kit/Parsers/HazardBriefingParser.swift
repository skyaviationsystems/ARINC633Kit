// HazardBriefingParser.swift
// ARINC633Kit
//
// Parser for the HazardBriefing message (root <HazardBriefing>, HazardBriefing.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, then HazardAdvisories are mapped to typed models, with any
// unrecognized children swept into each model's `extensions` bag.

import Foundation

/// Parses a `<HazardBriefing>` document into a `HazardBriefing`.
public final class HazardBriefingParser: Sendable {

    public init() {}

    /// Parse HazardBriefing XML into a typed `HazardBriefing`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> HazardBriefing {
        let root = try GenericElementParser().parse(data: data)

        var message = HazardBriefing(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        message.creationTime = root.attribute("creationTime")
        message.fullPackage = root.attribute("fullPackage").map { $0 == "true" || $0 == "1" }

        for advisoryEl in (root.firstDescendant(named: "HazardAdvisories")?.all(named: "HazardAdvisory") ?? []) {
            message.advisories.append(Self.advisory(from: advisoryEl))
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { $0.name != "HazardAdvisories" }
        return message
    }

    // MARK: - Advisory

    /// Names of child elements explicitly modeled on `HazardAdvisory`; the remainder is
    /// swept into the advisory's `extensions` bag.
    private static let modeledAdvisoryChildren: Set<String> = [
        "HazardType", "Airspaces", "HazardousArea", "HazardDetails",
        "Observation", "Forecasts", "Remark", "HazardAdvisoryText"
    ]

    private static func advisory(from el: CapturedElement) -> HazardAdvisory {
        var a = HazardAdvisory()
        a.hazardType = el.first(named: "HazardType")?.text.trimmedOrNil
        a.hazardDetails = el.first(named: "HazardDetails")?.text.trimmedOrNil
        a.remark = el.first(named: "Remark").map(Self.joinedText)
        a.advisoryText = el.first(named: "HazardAdvisoryText").map(Self.joinedText)

        // Attributes.
        a.issuer = el.attribute("issuer")
        a.source = el.attribute("source")
        a.advisoryNumber = el.attribute("advisoryNumber")
        a.startValidTime = el.attribute("startValidTime")
        a.endValidTime = el.attribute("endValidTime")
        a.observationTime = el.attribute("observationTime")
        a.nextInfo = el.attribute("nextinfo")
        a.startApplicabilityTime = el.attribute("startApplicabilityTime")
        a.endApplicabilityTime = el.attribute("endApplicabilityTime")
        a.sequence = el.attribute("sequence").flatMap { Int($0) }

        // Airspaces.
        a.airspaces = el.first(named: "Airspaces")?.all(named: "Airspace").map(Self.airspace) ?? []

        // Hazardous area.
        if let areaEl = el.first(named: "HazardousArea") {
            a.hazardousArea = Self.hazardousArea(from: areaEl)
        }

        // Observation (single extent) and forecasts (list of extents).
        if let obs = el.first(named: "Observation") {
            a.observation = Self.extent(from: obs, timeAttribute: "observationTime")
        }
        a.forecasts = el.first(named: "Forecasts")?.all(named: "Forecast")
            .map { Self.extent(from: $0, timeAttribute: "forecastTime") } ?? []

        a.extensions = el.children.filter { !modeledAdvisoryChildren.contains($0.name) }
        return a
    }

    private static func airspace(from el: CapturedElement) -> HazardAirspace {
        HazardAirspace(
            icaoCode: el.attribute("airspaceICAOCode"),
            name: el.first(named: "AirspaceName")?.text.trimmedOrNil
        )
    }

    private static func hazardousArea(from el: CapturedElement) -> HazardousArea {
        var area = HazardousArea()
        area.volcanoNumber = el.attribute("volcanoNumber")
        if let place = el.first(named: "PlaceName") {
            area.placeName = place.text.trimmedOrNil
            area.areaName = place.attribute("areaName")
        }
        if let coords = el.first(named: "Coordinates") {
            area.latitude = coords.attribute("latitude").flatMap { Double($0) }
            area.longitude = coords.attribute("longitude").flatMap { Double($0) }
        }
        area.elevation = el.altitude(of: "Elevation")
        return area
    }

    // MARK: - Extent (Observation / Forecast)

    private static func extent(from el: CapturedElement, timeAttribute: String) -> HazardExtent {
        var extent = HazardExtent()
        extent.time = el.attribute(timeAttribute)

        if let altitudes = el.first(named: "Altitudes") {
            // The bounded form uses explicit <Upper>/<Lower> children.
            extent.upperAltitude = altitudes.altitude(of: "Upper")
            extent.lowerAltitude = altitudes.altitude(of: "Lower")
            // The unbounded form uses one or more <Altitude> elements; a bound role may
            // be carried in the @upperLowerBound attribute.
            for altEl in altitudes.all(named: "Altitude") {
                guard let vu = altEl.valueAndUnit() else { continue }
                let alt = ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft/100")
                switch altEl.attribute("upperLowerBound")?.lowercased() {
                case "upper": if extent.upperAltitude == nil { extent.upperAltitude = alt }
                case "lower": if extent.lowerAltitude == nil { extent.lowerAltitude = alt }
                default:
                    // No explicit role: fill upper first, then lower.
                    if extent.upperAltitude == nil { extent.upperAltitude = alt }
                    else if extent.lowerAltitude == nil { extent.lowerAltitude = alt }
                }
            }
        }

        if let geography = el.first(named: "Geography") {
            extent.geography = geography
            extent.movementSpeed = geography.speed(of: "MovementSpeed")
            if let dir = geography.first(named: "MovementDirection")?.valueAndUnit() {
                extent.movementDirection = dir.value
            }
        }
        return extent
    }

    // MARK: - Text

    /// Join all `<Text>` descendants of a TextType element (handles `<Paragraph><Text>`),
    /// falling back to the element's own text when no `<Text>` children are present.
    private static func joinedText(_ el: CapturedElement) -> String {
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
