// TerrainClearance.swift
// ARINC633Kit
//
// Terrain profile data from <TerrainClearance>.

import Foundation

/// Terrain clearance profile data.
public struct TerrainClearance: Sendable, Equatable {
    /// Raw text entries if only unstructured data is available.
    public var entries: [String]

    public init() {
        self.entries = []
    }
}
