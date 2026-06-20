// OrganizedTracks.swift
// ARINC633Kit
//
// Organized Track System (OTS) model stub.
// Based on OrganizedTracks.xsd / RouteDefinition.xsd schemas.

import Foundation

/// Organized tracks message (e.g., North Atlantic Track system).
public struct OrganizedTracksMessage: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Track message identifier.
    public let trackMessageIdentifier: String?

    /// Track area (e.g., "NorthAtlantic").
    public let area: String?

    /// Raw content (for future full parsing).
    public let rawContent: String?

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                trackMessageIdentifier: String? = nil,
                area: String? = nil,
                rawContent: String? = nil) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.trackMessageIdentifier = trackMessageIdentifier
        self.area = area
        self.rawContent = rawContent
    }
}
