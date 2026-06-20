// AirportData.swift
// ARINC633Kit
//
// Airport details from <AirportDataList>.

import Foundation

/// Airport data entry with runway, procedures, and function.
public struct AirportData: Sendable, Equatable {
    /// Airport ICAO code.
    public var airportICAO: String?

    /// Airport IATA code.
    public var airportIATA: String?

    /// Airport name.
    public var airportName: String?

    /// Airport function (e.g., DepartureAirport, ETOPSAdequateAirport).
    public var airportFunction: AirportFunction

    /// Planned runway.
    public var plannedRunway: String?

    /// Terminal procedure (SID, STAR).
    public var terminalProcedures: [TerminalProcedure]

    /// Elevation in feet (from Elevation element).
    public var elevation: ARINCAltitude?

    /// Airport reference point coordinates.
    public var referencePoint: ARINCCoordinate?

    /// Magnetic variation at the airport.
    public var magneticVariation: Double?

    /// Local time offset to UTC (e.g., "-PT5H").
    public var localTimeOffsetToUTC: String?

    /// Runways with landing distance available.
    public var runways: [RunwayInfo]

    /// Whether airport is suitable for ETOPS regular operation.
    public var suitable: Bool?

    /// Suitable operation period start.
    public var suitablePeriodFrom: String?

    /// Suitable operation period end.
    public var suitablePeriodUntil: String?

    public init() {
        self.airportFunction = .unknown("")
        self.terminalProcedures = []
        self.runways = []
    }
}

/// Runway information with landing distance available.
public struct RunwayInfo: Sendable, Equatable {
    /// Runway identifier (e.g., "17R", "36L").
    public let identifier: String

    /// Landing distance available.
    public let landingDistanceAvailable: ARINCDistance?

    /// Whether the runway is approved for regular operation.
    public let approvedForRegularOperation: Bool

    public init(identifier: String, landingDistanceAvailable: ARINCDistance? = nil, approvedForRegularOperation: Bool = false) {
        self.identifier = identifier
        self.landingDistanceAvailable = landingDistanceAvailable
        self.approvedForRegularOperation = approvedForRegularOperation
    }
}

/// A terminal procedure (SID or STAR).
public struct TerminalProcedure: Sendable, Equatable {
    /// Procedure type (e.g., "SID", "STAR").
    public let procedureType: String

    /// Procedure name (e.g., "BNGOS4", "WITTI5").
    public let name: String

    public init(procedureType: String, name: String) {
        self.procedureType = procedureType
        self.name = name
    }
}
