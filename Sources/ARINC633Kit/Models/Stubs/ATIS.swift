// ATIS.swift
// ARINC633Kit
//
// ATIS (Automatic Terminal Information Service) model stub.
// Based on ATIS.xsd schema.

import Foundation

/// ATIS message containing terminal information for an airport.
public struct ATISMessage: Sendable, Equatable {
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
