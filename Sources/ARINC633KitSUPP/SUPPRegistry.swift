// SUPPRegistry.swift
// ARINC633KitSUPP
//
// Wires the optional Lido/vendor SUPP message types into a core
// `ARINC633MessageRegistry` via the custom-handler API.

import Foundation
import ARINC633Kit

public extension ARINC633MessageRegistry {

    /// Return a copy of this registry with Lido/vendor SUPP message types registered.
    ///
    /// Currently registers `AdditionalRemarks` (root `<AdditionalRemarks>`), surfaced
    /// as `ARINC633Message.custom(AdditionalRemarks)`. Compose on top of `.standard`:
    ///
    /// ```swift
    /// import ARINC633Kit
    /// import ARINC633KitSUPP
    ///
    /// let parser = ARINC633Parser(registry: .standard.registeringSUPP())
    /// if case let .custom(custom) = try parser.parse(data: xml),
    ///    let remarks = custom as? AdditionalRemarks {
    ///     // use remarks.crewQualifications, remarks.cduPreflight, ...
    /// }
    /// ```
    func registeringSUPP() -> ARINC633MessageRegistry {
        registering("AdditionalRemarks") { data in
            .custom(try AdditionalRemarksParser().parse(data: data))
        }
    }
}

public extension ARINC633Parser {
    /// A parser whose registry is `.standard` plus the optional SUPP vendor types.
    static func withSUPP() -> ARINC633Parser {
        ARINC633Parser(registry: .standard.registeringSUPP())
    }
}
