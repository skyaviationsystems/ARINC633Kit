// FUEL.swift
// ARINC633Kit
//
// FUEL message model stub.
// Based on REFUELING.xsd / CGTARGETING.xsd schemas.
// FUEL messages use various root elements: FCAIND, FDAACK, FDACOM, FDASUB,
// FENIND, FERIND, FORACK, FORSUB, FPRREP, FRCACK, FRCSUB, FSTREP, FSTREQ,
// FTBIND, FTEIND, FTIIND.

import Foundation

/// FUEL-related message (refueling, fuel status, CG targeting, etc.).
public struct FUELMessage: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// FUEL message subtype (root element name, e.g., FCAIND, FDASUB).
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
