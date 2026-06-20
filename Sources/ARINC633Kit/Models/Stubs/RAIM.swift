// RAIM.swift
// ARINC633Kit
//
// RAIM (Receiver Autonomous Integrity Monitoring) report model stub.
// Based on RAIMReport.xsd / RAIM.xsd schemas.

import Foundation

/// RAIM report containing GPS integrity predictions.
public struct RAIMReport: Sendable, Equatable {
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
