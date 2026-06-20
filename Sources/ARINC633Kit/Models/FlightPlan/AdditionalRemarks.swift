// AdditionalRemarks.swift
// ARINC633Kit
//
// Structured model for SUPP XML AdditionalRemarks data.
// Contains crew qualifications, CDU preflight, redispatch, permits, and more.

import Foundation

/// Parsed AdditionalRemarks from SUPP XML files.
///
/// Each SUPP XML contains Remark elements with typed sections identified by
/// RemarkType and Title attributes. This model structures those free-text
/// sections into typed fields for UI consumption.
public struct AdditionalRemarks: Sendable, Equatable {
    /// Release remarks text (Title="RELEASE REMARKS").
    public var releaseRemarks: String?

    /// Parsed crew qualification entries (Title="CREW QUALIFICATIONS").
    public var crewQualifications: [CrewQualification]

    /// Fuel notes text (Title="Fuel notes", RemarkType="FW").
    public var fuelNotes: String?

    /// Parsed redispatch information (Title="REDISPATCH INFO", RemarkType="EXTRAINFO").
    public var redispatchInfo: RedispatchInfo?

    /// Takeoff alternate text (Title="Takeoff Alternate", RemarkType="FW").
    public var takeoffAlternate: String?

    /// Parsed CDU preflight settings (Title="CDU Preflight").
    public var cduPreflight: CDUPreflight?

    /// Raw ETOPS INFO text (Title="ETOPS INFO") -- complex free-form content.
    public var etopsInfo: String?

    /// Parsed ETOPS INFO critical fuel scenario (structured from etopsInfo text).
    public var etopsInfoParsed: ETOPSInfoParsed?

    /// Parsed overflight permits (from "OVERFLIGHT/LANDING PERMITS" section).
    public var overflightPermits: [OverflightPermit]

    /// Parsed landing permits (from "OVERFLIGHT/LANDING PERMITS" section).
    public var landingPermits: [LandingPermit]

    /// Parsed CAT II/III approach authorizations.
    public var catApproaches: [CATApproach]

    /// All remarks in their original form for completeness.
    public var rawRemarks: [AdditionalRemark]

    /// Raw redispatch info text from FW section (Title="Redispatch Info", RemarkType="FW").
    public var fwRedispatchInfo: String?

    public init() {
        self.crewQualifications = []
        self.overflightPermits = []
        self.landingPermits = []
        self.catApproaches = []
        self.rawRemarks = []
    }
}

// MARK: - Sub-models

/// A crew member's qualification and currency data.
public struct CrewQualification: Sendable, Equatable {
    /// Rank code (e.g., "CA", "FO").
    public var rank: String
    /// Employee ID number.
    public var employeeId: String
    /// Crew member name.
    public var name: String
    /// Last takeoff date string.
    public var lastTakeoff: String?
    /// Last landing date string.
    public var lastLanding: String?
    /// Takeoff currency expiry date.
    public var takeoffExpiry: String?
    /// Landing currency expiry date.
    public var landingExpiry: String?

    public init(rank: String = "", employeeId: String = "", name: String = "") {
        self.rank = rank
        self.employeeId = employeeId
        self.name = name
    }
}

/// CDU (Control Display Unit) preflight settings.
public struct CDUPreflight: Sendable, Equatable {
    public var model: String?
    public var engines: String?
    public var fuelFactor: String?
    public var coRouteUplink: String?
    public var flightNumber: String?
    public var route: String?
    public var gdis: String?
    public var fmcReserves: String?
    public var cruiseAltitude: String?
    public var costIndex: String?
    public var wind: String?
    public var isaOat: String?

    public init() {}
}

/// Redispatch information from EXTRAINFO section.
public struct RedispatchInfo: Sendable, Equatable {
    /// Redispatch airport name/code from header.
    public var airport: String?
    /// Redispatch airport ICAO code.
    public var airportICAO: String?
    /// Estimated time of arrival.
    public var eta: String?
    /// Decision point identifier.
    public var decisionPoint: String?
    /// Planned landing weight.
    public var planLandingWeight: String?
    /// Initial airport details.
    public var initialAirport: RedispatchAirportDetail?
    /// Initial alternate airport details.
    public var initialAlternate: RedispatchAirportDetail?

    public init() {}
}

/// Detail for a redispatch airport (initial or alternate).
public struct RedispatchAirportDetail: Sendable, Equatable {
    /// Airport ICAO code.
    public var airportICAO: String
    /// Fuel required (kg).
    public var fuel: Int?
    /// Time to reach.
    public var time: String?
    /// Distance (NM).
    public var distance: Int?
    /// Minimum off-route altitude.
    public var mora: Int?
    /// Route description.
    public var route: String?

    public init(airportICAO: String = "") {
        self.airportICAO = airportICAO
    }
}

/// An overflight permit entry.
public struct OverflightPermit: Sendable, Equatable {
    /// Country name.
    public var country: String
    /// Permit number/reference.
    public var permitNumber: String
    /// Optional "VALID FOR" notation.
    public var validFor: String?

    public init(country: String = "", permitNumber: String = "") {
        self.country = country
        self.permitNumber = permitNumber
    }
}

/// A landing permit entry.
public struct LandingPermit: Sendable, Equatable {
    /// Country name.
    public var country: String
    /// Permit number/reference.
    public var permitNumber: String

    public init(country: String = "", permitNumber: String = "") {
        self.country = country
        self.permitNumber = permitNumber
    }
}

/// A CAT II/III approach authorization.
public struct CATApproach: Sendable, Equatable {
    /// Airport ICAO code.
    public var airportICAO: String
    /// Category (e.g., "CAT II/III", "CAT II").
    public var category: String
    /// Authorized runway designators.
    public var runways: String

    public init(airportICAO: String = "", category: String = "", runways: String = "") {
        self.airportICAO = airportICAO
        self.category = category
        self.runways = runways
    }
}

/// Parsed ETOPS INFO critical fuel scenario from SUPP XML.
public struct ETOPSInfoParsed: Sendable, Equatable {
    /// ETOPS type string (e.g., "60/180").
    public var etopsType: String?
    /// Scenario name (e.g., "DEPRESS").
    public var scenario: String?
    /// Aircraft type (e.g., "B777F").
    public var aircraftType: String?
    /// Weight unit (e.g., "KG").
    public var unit: String?
    /// ETP name (e.g., "ETP1").
    public var etpName: String?
    /// Suitable airports string (e.g., "PACD-RJSS").
    public var etpAirports: String?
    /// Latitude string (e.g., "N51 25.9").
    public var latitude: String?
    /// Longitude string (e.g., "E163 16.0").
    public var longitude: String?
    /// Diversion airport detail rows.
    public var airportRows: [ETOPSInfoAirportRow]
    /// Remarks line (e.g., "MINF INCL APU / 5.0 Percent Total WIND ...").
    public var remarks: String?
    /// Last adequate airport ICAO.
    public var lastAdequate: String?
    /// First adequate airport ICAO.
    public var firstAdequate: String?

    public init() {
        self.airportRows = []
    }
}

/// A diversion airport row from ETOPS INFO critical fuel scenario.
public struct ETOPSInfoAirportRow: Sendable, Equatable {
    /// Airport ICAO code.
    public var icao: String
    /// MORA in hundreds of feet.
    public var mora: Int?
    /// Track in degrees.
    public var track: Int?
    /// Distance in NM.
    public var distance: Int?
    /// Time string (e.g., "04:19").
    public var time: String?
    /// Remaining fuel in kg.
    public var remainingFuel: Int?
    /// PAD fuel in kg.
    public var pad: Int?
    /// Minimum fuel in kg.
    public var minimumFuel: Int?
    /// Weather window (e.g., "2143Z-0441Z").
    public var wxWindow: String?

    public init(icao: String = "") {
        self.icao = icao
    }
}

/// A raw additional remark preserving original structure.
public struct AdditionalRemark: Sendable, Equatable {
    /// The RemarkType attribute value.
    public var remarkType: String
    /// The Title attribute value.
    public var title: String
    /// The raw text content.
    public var text: String

    public init(remarkType: String = "", title: String = "", text: String = "") {
        self.remarkType = remarkType
        self.title = title
        self.text = text
    }
}
