// ATISParser.swift
// ARINC633Kit
//
// Parser for the ATIS message (root <ATIS>, ATIS.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted
// via CapturedElement helpers, then ATISBulletins are mapped to typed models, with
// any unrecognized children swept into the model's `extensions` bag.

import Foundation

/// Parses an `<ATIS>` document into an `ATISMessage`.
public final class ATISParser: Sendable {

    public init() {}

    /// Parse ATIS XML into a typed `ATISMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> ATISMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = ATISMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        for bulletinEl in (root.firstDescendant(named: "ATISBulletins")?.all(named: "ATISBulletin") ?? []) {
            message.bulletins.append(Self.bulletin(from: bulletinEl))
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { $0.name != "ATISBulletins" }
        return message
    }

    private static func bulletin(from el: CapturedElement) -> ATISBulletin {
        var b = ATISBulletin()
        let airport = el.first(named: "Airport")
        b.airportICAO = airport?.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil
        b.airportIATA = airport?.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
        b.airportName = airport?.attribute("airportName")

        b.isDeparture = el.attribute("departureType").map { $0 == "true" || $0 == "1" }
        b.isDemand = el.attribute("demandType").map { $0 == "true" || $0 == "1" }
        b.informationIndicator = el.attribute("informationIndicator")
        b.observationTime = el.attribute("observationTime")
        b.observationType = el.attribute("observationType")
        b.sequence = el.attribute("sequence").flatMap { Int($0) }

        if let details = el.first(named: "ATISDetails") {
            for approachEl in (details.first(named: "ExpectedApproaches")?.all(named: "ExpectedApproach") ?? []) {
                var approach = ATISExpectedApproach(approachType: approachEl.attribute("approachType"))
                approach.runways = approachEl.first(named: "Runways")?.all(named: "Runway").map(Self.runway) ?? []
                b.expectedApproaches.append(approach)
            }
            // "Runways in use" is the second (required) <Runways> sibling, not the one
            // nested under an approach.
            b.runwaysInUse = details.all(named: "Runways").last?.all(named: "Runway").map(Self.runway) ?? []
            b.significantRunwayCondition = details.first(named: "SignificantRunwayCondition")?.text.trimmedOrNil
            b.transitionLevel = details.altitude(of: "TransitionLevel")
            b.holdingDelay = details.first(named: "HoldingDelay")?.text.trimmedOrNil
            b.otherEssentialOperationalInformation = details.first(named: "OtherEssentialOperationalInformation")?.text.trimmedOrNil
            b.comment = details.first(named: "Comment")?.text.trimmedOrNil
            b.observation = details.first(named: "Observation")
        }

        // ATISText: join all <Text> descendants.
        if let atisText = el.first(named: "ATISText") {
            let texts = Self.collectText(atisText)
            b.atisText = texts.isEmpty ? atisText.text.trimmedOrNil : texts.joined(separator: "\n")
        }
        return b
    }

    private static func runway(from el: CapturedElement) -> ATISRunway {
        ATISRunway(runwayIdentifier: el.attribute("runwayIdentifier") ?? el.text.trimmingCharacters(in: .whitespacesAndNewlines),
                   type: el.attribute("type"))
    }

    /// Collect text from all `<Text>` descendants (handles `<Paragraph><Text>`).
    private static func collectText(_ el: CapturedElement) -> [String] {
        var out: [String] = []
        func walk(_ node: CapturedElement) {
            if node.name == "Text", let t = node.text.trimmedOrNil { out.append(t) }
            node.children.forEach(walk)
        }
        walk(el)
        return out
    }
}
