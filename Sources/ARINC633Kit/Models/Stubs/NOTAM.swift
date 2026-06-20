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

    /// Remark prose from the `Remark` element (TextType -> Paragraph/Text), kept
    /// separate from the decoded NOTAM body `text`. Distinct schema element; routing
    /// it here prevents it being concatenated into `text`.
    public var remark: String?

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

    /// Upper altitude limit (truncated integer) from `Altitudes/Upper/Value`.
    /// Retained for source compatibility; prefer `upperAltitudeMeasured`, which
    /// preserves the float value and `@unit`.
    public var upperAltitude: Int?

    /// Lower altitude limit (truncated integer) from `Altitudes/Lower/Value`.
    /// Retained for source compatibility; prefer `lowerAltitudeMeasured`, which
    /// preserves the float value and `@unit`.
    public var lowerAltitude: Int?

    /// Upper altitude limit from `Altitudes/Upper/Value`, with the value (`xs:float`)
    /// and its `@unit` (default "ft/100" per schema) preserved. This is the lossless
    /// form of `upperAltitude`.
    public var upperAltitudeMeasured: ARINCAltitude?

    /// Lower altitude limit from `Altitudes/Lower/Value`, with value and `@unit`
    /// preserved (default "ft/100"). Lossless form of `lowerAltitude`.
    public var lowerAltitudeMeasured: ARINCAltitude?

    /// Bare applicability altitudes from the `AltitudeInfoType` choice where repeating
    /// `<Altitude>` (no Upper/Lower bound) elements appear. Each preserves value+`@unit`.
    public var altitudes: [ARINCAltitude]

    /// ICAO Q-code first qualifier (e.g., "MX") from `ICAONOTAMInformation/@qcode1`.
    public var qcode1: String?

    /// ICAO Q-code second qualifier (e.g., "LC") from `ICAONOTAMInformation/@qcode2`.
    public var qcode2: String?

    /// Traffic indicator from `ICAONOTAMInformation/@trafficIndicator` (e.g., "IV").
    public var trafficIndicator: String?

    /// Scope from `ICAONOTAMInformation/@scope` (e.g., "A" for aerodrome).
    public var scope: String?

    /// Purpose from `ICAONOTAMInformation/@purpose` (e.g., "O" operationally significant).
    public var purpose: String?

    /// FIR / location identifier from `ICAONOTAMInformation/@fIR` (e.g., "ESSA").
    public var fIR: String?

    /// Lower applicability altitude from `ICAONOTAMInformation/@lowerAlt` (integer 0–999).
    public var lowerAlt: Int?

    /// Upper applicability altitude from `ICAONOTAMInformation/@upperAlt` (integer 0–999).
    public var upperAlt: Int?

    /// Decoded ICAO NOTAM Item A (location) from `ICAONOTAMInformation/ItemA`.
    public var itemA: String?

    /// Decoded ICAO NOTAM Item B (start of validity) from `ICAONOTAMInformation/ItemB`.
    public var itemB: String?

    /// Decoded ICAO NOTAM Item C (end of validity) from `ICAONOTAMInformation/ItemC`.
    public var itemC: String?

    /// Decoded ICAO NOTAM Item D (schedule) from `ICAONOTAMInformation/ItemD`.
    public var itemD: String?

    /// Decoded ICAO NOTAM Item F (lower limit) from `ICAONOTAMInformation/ItemF`.
    public var itemF: String?

    /// Decoded ICAO NOTAM Item G (upper limit) from `ICAONOTAMInformation/ItemG`.
    public var itemG: String?

    /// NOTAM priority/operational criticality (`@priority`, 1 = highest, default 3).
    public var priority: Int?

    /// Whether the NOTAM was considered in the flight plan (`@consideredInFlightPlan`).
    public var consideredInFlightPlan: Bool?

    /// Start-applicability time (`@startApplicabilityTime`, ISO 8601) — company margin
    /// that can extend `startValidTime`.
    public var startApplicabilityTime: String?

    /// End-applicability time (`@endApplicabilityTime`, ISO 8601).
    public var endApplicabilityTime: String?

    /// Unrecognized child elements of this NOTAM, preserved verbatim.
    public var extensions: [CapturedElement]

    public init(serial: String? = nil, series: String? = nil, year: String? = nil,
                issuer: String? = nil, source: String? = nil,
                startValidTime: String? = nil, endValidTime: String? = nil,
                creationTime: String? = nil,
                text: String? = nil, remark: String? = nil, airport: String? = nil,
                airports: [String] = [], airspaces: [String] = [],
                subjects: [String] = [], severity: String? = nil,
                endValidTimeQualifier: String? = nil, issuerType: String? = nil,
                revisionTime: String? = nil, sequence: Int? = nil,
                briefingSections: [String] = [],
                upperAltitude: Int? = nil, lowerAltitude: Int? = nil,
                upperAltitudeMeasured: ARINCAltitude? = nil,
                lowerAltitudeMeasured: ARINCAltitude? = nil,
                altitudes: [ARINCAltitude] = [],
                qcode1: String? = nil, qcode2: String? = nil,
                trafficIndicator: String? = nil, scope: String? = nil,
                purpose: String? = nil, fIR: String? = nil,
                lowerAlt: Int? = nil, upperAlt: Int? = nil,
                itemA: String? = nil, itemB: String? = nil, itemC: String? = nil,
                itemD: String? = nil, itemF: String? = nil, itemG: String? = nil,
                priority: Int? = nil, consideredInFlightPlan: Bool? = nil,
                startApplicabilityTime: String? = nil,
                endApplicabilityTime: String? = nil,
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
        self.remark = remark
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
        self.upperAltitudeMeasured = upperAltitudeMeasured
        self.lowerAltitudeMeasured = lowerAltitudeMeasured
        self.altitudes = altitudes
        self.qcode1 = qcode1
        self.qcode2 = qcode2
        self.trafficIndicator = trafficIndicator
        self.scope = scope
        self.purpose = purpose
        self.fIR = fIR
        self.lowerAlt = lowerAlt
        self.upperAlt = upperAlt
        self.itemA = itemA
        self.itemB = itemB
        self.itemC = itemC
        self.itemD = itemD
        self.itemF = itemF
        self.itemG = itemG
        self.priority = priority
        self.consideredInFlightPlan = consideredInFlightPlan
        self.startApplicabilityTime = startApplicabilityTime
        self.endApplicabilityTime = endApplicabilityTime
        self.extensions = extensions
    }
}
