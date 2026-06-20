// AirspaceData.swift
// ARINC633Kit
//
// Airspace data model stub.
// Based on AirspaceData.xsd schema.

import Foundation

/// Airspace data message containing airspace restrictions and information.
public struct AirspaceDataMessage: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Raw content (for future full parsing).
    public let rawContent: String?

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                rawContent: String? = nil) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.rawContent = rawContent
    }
}
