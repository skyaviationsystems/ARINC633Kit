// EstimatedActual.swift
// ARINC633Kit
//
// Generic wrapper for fields that have both estimated and actual values.
// Replaces per-type wrappers (SpeedBasic, AltitudeBasic, etc.) from the XSD.

import Foundation

/// Generic container for estimated/actual value pairs common in ARINC 633.
///
/// Many ARINC 633 fields have both estimated and actual values
/// (e.g., `<EstimatedWeight>` and `<ActualWeight>`).
/// The `resolved` property returns actual when available, falling back to estimated.
public struct EstimatedActual<T: Sendable & Equatable>: Sendable, Equatable {
    public var estimated: T?
    public var actual: T?

    /// Returns actual if available, otherwise estimated.
    public var resolved: T? {
        actual ?? estimated
    }

    public init(estimated: T? = nil, actual: T? = nil) {
        self.estimated = estimated
        self.actual = actual
    }
}
