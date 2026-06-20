// NOTAM.swift
// ARINC633Kit
//
// NOTAM briefing model.
// Based on NotamBriefing.xsd / Notam.xsd schemas.

import Foundation

/// NOTAM (Notice to Airmen) briefing containing flight-relevant notices.
public struct NOTAMBriefing: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public var header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public var supplementaryHeader: SupplementaryHeader

    /// Briefing type description (e.g., "Cockpit").
    public var briefingType: String?

    /// Creation time of the briefing (ISO 8601).
    public var creationTime: String?

    /// Whether this is a full briefing package.
    public var fullPackage: Bool

    /// Individual NOTAM items.
    public var notams: [NOTAMItem]

    /// Unrecognized child elements of the briefing, preserved verbatim.
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                briefingType: String? = nil,
                creationTime: String? = nil,
                fullPackage: Bool = false,
                notams: [NOTAMItem] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.briefingType = briefingType
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.notams = notams
        self.extensions = extensions
    }
}

/// Individual NOTAM item with full ARINC 633 attributes.
public struct NOTAMItem: Sendable, Equatable {
    /// NOTAM serial number.
    public var serial: String?

    /// NOTAM series identifier (e.g., "A").
    public var series: String?

    /// Issuing year (e.g., "2026").
    public var year: String?

    /// Issuing authority (e.g., "EBBR").
    public var issuer: String?

    /// Source of the NOTAM (e.g., "EAD").
    public var source: String?

    /// Start of validity period (ISO 8601).
    public var startValidTime: String?

    /// End of validity period (ISO 8601).
    public var endValidTime: String?

    /// Creation time of the NOTAM (ISO 8601).
    public var creationTime: String?

    /// NOTAM text content from NOTAMText/Paragraph/Text elements.
    public var text: String?

    /// First affected airport ICAO code (from Keys/Airports). Convenience accessor;
    /// see `airports` for the full list when a NOTAM affects several.
    public var airport: String?

    /// All affected airport ICAO codes (`Keys/Airports/Airport/AirportICAOCode`).
    public var airports: [String]

    /// Affected airspace ICAO codes (`Keys/Airspaces/Airspace/AirspaceICAOCode`).
    public var airspaces: [String]

    /// NOTAM subject keyword(s) (`NOTAMSubjects/NOTAMSubject`), e.g. "Runway",
    /// "Airport", "Airspace". (These are the real 633-4 subject values — the field is
    /// NOT a "sev:"-encoded severity.)
    public var subjects: [String]

    /// Deprecated: never populated by ARINC 633-4 data (the prior "sev:" convention does
    /// not exist in the spec). Use `subjects`. Retained for source compatibility.
    public var severity: String?

    /// End-validity qualifier (`@endValidTimeQualifier`), e.g. "PERM"/"EST" when present.
    public var endValidTimeQualifier: String?

    /// Issuer type (`@issuerType`), e.g. "ICAO".
    public var issuerType: String?

    /// Revision time (`@revisionTime`, ISO 8601), when present.
    public var revisionTime: String?

    /// Display/order sequence (`@sequence`), when present.
    public var sequence: Int?

    /// Briefing section categories (e.g., "RUNWAY", "GENERAL", "COMMUNICATION").
    public var briefingSections: [String]

    /// Upper altitude limit in feet from Altitudes/Upper/Value.
    public var upperAltitude: Int?

    /// Lower altitude limit in feet from Altitudes/Lower/Value.
    public var lowerAltitude: Int?

    /// ICAO Q-code first qualifier (e.g., "MX").
    public var qcode1: String?

    /// ICAO Q-code second qualifier (e.g., "LC").
    public var qcode2: String?

    /// Traffic indicator from ICAONOTAMInformation (e.g., "IV").
    public var trafficIndicator: String?

    /// Scope from ICAONOTAMInformation (e.g., "A" for aerodrome).
    public var scope: String?

    /// Unrecognized child elements of this NOTAM, preserved verbatim.
    public var extensions: [CapturedElement]

    public init(serial: String? = nil, series: String? = nil, year: String? = nil,
                issuer: String? = nil, source: String? = nil,
                startValidTime: String? = nil, endValidTime: String? = nil,
                creationTime: String? = nil,
                text: String? = nil, airport: String? = nil,
                airports: [String] = [], airspaces: [String] = [],
                subjects: [String] = [], severity: String? = nil,
                endValidTimeQualifier: String? = nil, issuerType: String? = nil,
                revisionTime: String? = nil, sequence: Int? = nil,
                briefingSections: [String] = [],
                upperAltitude: Int? = nil, lowerAltitude: Int? = nil,
                qcode1: String? = nil, qcode2: String? = nil,
                trafficIndicator: String? = nil, scope: String? = nil,
                extensions: [CapturedElement] = []) {
        self.serial = serial
        self.series = series
        self.year = year
        self.issuer = issuer
        self.source = source
        self.startValidTime = startValidTime
        self.endValidTime = endValidTime
        self.creationTime = creationTime
        self.text = text
        self.airport = airport
        self.airports = airports
        self.airspaces = airspaces
        self.subjects = subjects
        self.severity = severity
        self.endValidTimeQualifier = endValidTimeQualifier
        self.issuerType = issuerType
        self.revisionTime = revisionTime
        self.sequence = sequence
        self.briefingSections = briefingSections
        self.upperAltitude = upperAltitude
        self.lowerAltitude = lowerAltitude
        self.qcode1 = qcode1
        self.qcode2 = qcode2
        self.trafficIndicator = trafficIndicator
        self.scope = scope
        self.extensions = extensions
    }
}
