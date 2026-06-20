// WBA.swift
// ARINC633Kit
//
// Weight & Balance Amendment model stub.
// Based on WBA.xsd / WBAcommon.xsd schemas.
// WBA messages use WIFSUB, WIISUB, WIMSUB, WIRREP root elements.

import Foundation

/// Weight & Balance Amendment message.
public struct WBAMessage: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// WBA message subtype (e.g., WIFSUB, WIISUB, WIMSUB, WIRREP).
    public let messageSubtype: String?

    /// Raw content (for future full parsing).
    public let rawContent: String?

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                messageSubtype: String? = nil,
                rawContent: String? = nil) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.messageSubtype = messageSubtype
        self.rawContent = rawContent
    }
}
