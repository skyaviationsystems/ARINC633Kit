// DeIcingParser.swift
// ARINC633Kit
//
// Parser for the DeIcing message family (roots DORSUB, DORACK, DORIND, DPRREP,
// DRCSUB, DRCACK; DEICING.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted
// via CapturedElement helpers, `messageSubtype` is set from the root element's local
// name, then the shared payload is populated from whichever elements the subtype
// carries. Unrecognized top-level payload children are swept into `extensions`.

import Foundation

/// Parses any DeIcing-family document into a `DeIcingMessage`.
public final class DeIcingParser: Sendable {

    public init() {}

    /// Parse DeIcing XML into a typed `DeIcingMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> DeIcingMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = DeIcingMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            messageSubtype: root.name
        )

        // MARK: Order routing (DORSUB / DORACK / DRCSUB)
        // ServiceAirport carries the ICAO code as element text.
        message.serviceAirport = root.first(named: "ServiceAirport")?.text.trimmedOrNil
        // Provider id spelled "DeIcingProviderID" in DOR*, "DeIcingProviderId" in DRC*.
        message.deIcingProviderID = (root.first(named: "DeIcingProviderID")
                                     ?? root.first(named: "DeIcingProviderId"))?.text.trimmedOrNil
        message.serviceFlight = root.first(named: "ServiceFlight")?.text.trimmedOrNil
        message.deicingRequired = boolAttr(root.attribute("deicingRequiredIndicator"))
        message.acknowledgementRequired = boolAttr(root.attribute("acknowledgementRequired"))

        // MARK: Order indication (DORIND)
        if let place = root.first(named: "DeIcingPlace") {
            message.deIcingPlace = place.text.trimmedOrNil
            message.deIcingPlaceType = place.attribute("deIcingPlaceType")
        }
        message.estimatedBeginTime = root.first(named: "EstimatedDe-IcingBeginTime")?.text.trimmedOrNil
        message.estimatedEndTime = root.first(named: "EstimatedDe-IcingEndTime")?.text.trimmedOrNil
        message.deIcingSequenceNumber = root.first(named: "DeIcingSequenceNumber")?.intValue
        message.deIcingOpsIndicator = root.attribute("deIcingOpsIndicator")

        // MARK: Receipt routing (DRCSUB)
        message.deIcingReceiptNumber = root.first(named: "DeIcingReceiptNumber")?.text.trimmedOrNil

        // MARK: Treatment payload (DPRREP / DRCSUB / DRCACK)
        if let antiIcing = root.first(named: "AntiIcing") {
            message.treatment = Self.treatment(from: antiIcing, isAntiIcing: true)
        } else if let deIcingOnly = root.first(named: "DeIcingOnly") {
            message.treatment = Self.treatment(from: deIcingOnly, isAntiIcing: false)
        } else if let code = root.first(named: "AntiIcingCode") {
            // DRCACK: a bare anti-icing code with no de-icing data.
            var t = DeIcingTreatment(isAntiIcing: true)
            Self.applyAntiIcingCode(code, to: &t)
            message.treatment = t
        }

        // MARK: Free text
        message.remark = Self.remarkText(root.first(named: "Remark"))

        // Preserve any unmodeled top-level payload children.
        let mapped: Set<String> = [
            "ServiceAirport", "DeIcingProviderID", "DeIcingProviderId", "ServiceFlight",
            "DeIcingPlace", "EstimatedDe-IcingBeginTime", "EstimatedDe-IcingEndTime",
            "DeIcingSequenceNumber", "DeIcingReceiptNumber",
            "AntiIcing", "DeIcingOnly", "AntiIcingCode", "Remark"
        ]
        message.extensions = root.payloadChildren.filter { !mapped.contains($0.name) }
        return message
    }

    // MARK: - Treatment

    /// Build a treatment from a `<DeIcingOnly>` or `<AntiIcing>` element. The de-icing
    /// data group is read directly; the anti-icing groups (when present) are read from
    /// the nested `<AntiIcingCode>` wrapper plus the optional end-time / volume
    /// siblings that follow it.
    private static func treatment(from el: CapturedElement, isAntiIcing: Bool) -> DeIcingTreatment {
        var t = DeIcingTreatment(isAntiIcing: isAntiIcing)

        // deIcingData.Grp
        t.deIcingFluidType = el.first(named: "DeIcingFluidType")?.intValue
        t.deIcingFluidMix = el.first(named: "DeIcingFluidMix")?.intValue
        t.actualDeIcingBeginTime = el.first(named: "ActualDeIcingBeginTime")?.text.trimmedOrNil
        t.actualDeIcingEndTime = el.first(named: "ActualDeIcingEndTime")?.text.trimmedOrNil
        t.deIcingFluidVolume = volume(el.first(named: "DeIcingFluidVolume"))

        if isAntiIcing {
            // antiIcingCode.Grp lives under the <AntiIcingCode> wrapper in samples;
            // fall back to the element itself if a flat layout is encountered.
            let code = el.first(named: "AntiIcingCode") ?? el
            applyAntiIcingCode(code, to: &t)

            // antiIcingData.Grp tail: end time and fluid volume are siblings of the code.
            t.actualAntiIcingEndTime = el.first(named: "ActualAntiIcingEndTime")?.text.trimmedOrNil
            t.antiIcingFluidVolume = volume(el.first(named: "AntiIcingFluidVolume"))
        }
        return t
    }

    /// Populate the anti-icing code fields (antiIcingCode.Grp) from a wrapper element.
    private static func applyAntiIcingCode(_ code: CapturedElement, to t: inout DeIcingTreatment) {
        t.antiIcingFluidType = code.first(named: "AntiIcingFluidType")?.intValue
        t.antiIcingFluidBrand = code.first(named: "AntiIcingFluidBrand")?.intValue
        t.antiIcingFluidMix = code.first(named: "AntiIcingFluidMix")?.intValue
        t.actualAntiIcingBeginTime = code.first(named: "ActualAntiIcingBeginTime")?.text.trimmedOrNil
    }

    // MARK: - Helpers

    /// A `DeIcingFluidVolume` / `AntiIcingFluidVolume` element: integer text with the
    /// unit carried as the element's own `unit` attribute (volumeUnitType).
    private static func volume(_ el: CapturedElement?) -> ARINCVolume? {
        guard let el, let v = el.doubleValue else { return nil }
        if let u = el.attribute("unit") {
            return ARINCVolume(value: v, unit: u)
        }
        return ARINCVolume(value: v)
    }

    /// Collect `<Remark>/<Paragraph>/<Text>` content, paragraphs joined by newlines.
    private static func remarkText(_ el: CapturedElement?) -> String? {
        guard let el else { return nil }
        var out: [String] = []
        func walk(_ node: CapturedElement) {
            if node.name == "Text", let t = node.text.trimmedOrNil { out.append(t) }
            node.children.forEach(walk)
        }
        walk(el)
        if out.isEmpty { return el.text.trimmedOrNil }
        return out.joined(separator: "\n")
    }
}

private func boolAttr(_ raw: String?) -> Bool? {
    guard let raw else { return nil }
    return raw == "true" || raw == "1"
}
