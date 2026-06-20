// FuelStatistics.swift
// ARINC633Kit
//
// Statistical fuel analysis from <FuelStatistics>.

import Foundation

/// Statistical fuel analysis data.
public struct FuelStatistics: Sendable, Equatable {
    /// Raw text entries if only unstructured data is available.
    public var entries: [String]

    public init() {
        self.entries = []
    }
}
