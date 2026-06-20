// ARINC633CustomMessage.swift
// ARINC633Kit
//
// Extensibility point for airline / vendor message types that are not part of
// ARINC 633-4 core. Custom handlers registered on `ARINC633MessageRegistry`
// return their parsed payload wrapped in `ARINC633Message.custom(...)`.

import Foundation

/// A message type contributed by an integrator rather than ARINC 633-4 core.
///
/// Conform a value type to this protocol and register a handler for its root
/// element(s) via `ARINC633MessageRegistry.registering(_:_:)`. The handler returns
/// `.custom(myMessage)`. This is exactly how the optional `ARINC633KitSUPP` module
/// surfaces Lido `AdditionalRemarks` (a vendor SUPP extension that is intentionally
/// **not** part of the core kit).
public protocol ARINC633CustomMessage: Sendable {
    /// The XML root element name this message was parsed from.
    var rootElement: String { get }
}
