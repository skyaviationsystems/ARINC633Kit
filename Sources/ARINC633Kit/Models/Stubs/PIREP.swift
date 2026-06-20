// PIREP.swift
// ARINC633Kit
//
// PIREP (Pilot Report) briefing model stub.
// Based on PIREPBriefing.xsd / PIREP.xsd schemas.

import Foundation

/// PIREP briefing containing pilot weather reports.
public struct PIREPBriefing: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Creation time of the briefing.
    public let creationTime: String?

    /// Whether this is a full briefing package.
    public let fullPackage: Bool

    /// Raw content (for future full parsing).
    public let rawContent: String?

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                creationTime: String? = nil,
                fullPackage: Bool = false,
                rawContent: String? = nil) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.rawContent = rawContent
    }
}
