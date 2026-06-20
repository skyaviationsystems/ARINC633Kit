// TankeringInfo.swift
// ARINC633Kit
//
// Tankering economics from <TankeringInfo>.

import Foundation

/// Tankering (carrying extra fuel for economic reasons) information.
public struct TankeringInfo: Sendable, Equatable {
    /// Raw text entries if only unstructured data is available.
    public var entries: [String]

    public init() {
        self.entries = []
    }
}
