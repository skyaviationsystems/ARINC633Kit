// CapturedElement+Values.swift
// ARINC633Kit
//
// Numeric / measurement extraction helpers for tree-walk parsers. ARINC 633 encodes
// physical quantities as `<Value unit="...">N</Value>` elements; these helpers turn
// those into Foundation value types that preserve unit context.

import Foundation

public extension CapturedElement {

    /// This element's text as an `Int`, if parseable.
    var intValue: Int? { Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) }

    /// This element's text as a `Double`, if parseable.
    var doubleValue: Double? { Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) }

    /// The `(value, unit)` of a `<Value unit="...">N</Value>` element found anywhere in
    /// the subtree, or `nil`. If `self` is already a `<Value>`, it is used directly.
    func valueAndUnit() -> (value: Double, unit: String?)? {
        let valueEl = (name == "Value") ? self : firstDescendant(named: "Value")
        guard let valueEl, let v = valueEl.doubleValue else { return nil }
        return (v, valueEl.attribute("unit"))
    }

    /// The `<Value>` of a named descendant as an `ARINCAltitude` (default unit "ft/100").
    func altitude(of childName: String) -> ARINCAltitude? {
        guard let vu = firstDescendant(named: childName)?.valueAndUnit() else { return nil }
        return ARINCAltitude(value: vu.value, unit: vu.unit ?? "ft/100")
    }

    /// The `<Value>` of a named descendant as an `ARINCDistance` (default unit "NM").
    func distance(of childName: String) -> ARINCDistance? {
        guard let vu = firstDescendant(named: childName)?.valueAndUnit() else { return nil }
        return ARINCDistance(value: vu.value, unit: vu.unit ?? "NM")
    }

    /// The `<Value>` of a named descendant as an `ARINCWeight` (default unit "kg").
    func weight(of childName: String) -> ARINCWeight? {
        guard let vu = firstDescendant(named: childName)?.valueAndUnit() else { return nil }
        return ARINCWeight(value: vu.value, unit: vu.unit ?? "kg")
    }

    /// The `<Value>` of a named descendant as an `ARINCSpeed` (default unit "kt").
    func speed(of childName: String) -> ARINCSpeed? {
        guard let vu = firstDescendant(named: childName)?.valueAndUnit() else { return nil }
        return ARINCSpeed(value: vu.value, unit: vu.unit ?? "kt")
    }

    /// The `<Value>` of a named descendant as an `ARINCTemperature` (default unit "C").
    func temperature(of childName: String) -> ARINCTemperature? {
        guard let vu = firstDescendant(named: childName)?.valueAndUnit() else { return nil }
        return ARINCTemperature(value: vu.value, unit: vu.unit ?? "C")
    }

    /// Payload children excluding the message envelope (header / supplementary header).
    var payloadChildren: [CapturedElement] {
        children.filter { !CapturedElement.envelopeChildNames.contains($0.name) }
    }
}
