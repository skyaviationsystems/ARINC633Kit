// DeIcing.swift
// ARINC633Kit
//
// De-Icing message model stub.
// Based on DEICING.xsd schema.
// DeIcing messages use root elements: DORACK, DORIND, DORSUB, DPRREP,
// DRCACK, DRCSUB.

import Foundation

/// De-Icing message (de-icing order, report, status, etc.).
public struct DeIcingMessage: Sendable, Equatable {
    /// Root elements that map to a De-Icing message (per DEICING.xsd).
    public static let rootElements = ["DORACK", "DORIND", "DORSUB", "DPRREP", "DRCACK", "DRCSUB"]

    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// De-Icing message subtype (root element name, e.g., DORACK, DPRREP).
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
