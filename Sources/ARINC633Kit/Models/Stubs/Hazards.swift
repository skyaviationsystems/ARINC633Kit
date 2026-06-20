// Hazards.swift
// ARINC633Kit
//
// Hazard advisory briefing model stub.
// Based on HazardBriefing.xsd / HazardAdvisory.xsd schemas.

import Foundation

/// Hazard advisory briefing containing hazard warnings.
public struct HazardBriefing: Sendable, Equatable {
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
