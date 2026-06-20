// ARINC633Header.swift
// ARINC633Kit
//
// Header types for ARINC 633 message envelope (M633Header, M633SupplementaryHeader).
// Based on m633headers.xsd schema.

import Foundation

// MARK: - M633Header

/// Standard ARINC 633 message header from `<M633Header>`.
public struct ARINC633Header: Sendable, Equatable {
    /// ARINC 633 version number (e.g., "3" for Atlas Air, "5" for recent spec).
    public let versionNumber: String

    /// Message creation timestamp (ISO 8601).
    public let timestamp: String

    /// Optional message sequence identifier.
    public let messageSequence: String?

    public init(versionNumber: String = "", timestamp: String = "", messageSequence: String? = nil) {
        self.versionNumber = versionNumber
        self.timestamp = timestamp
        self.messageSequence = messageSequence
    }
}

// MARK: - Supplementary Header

/// Supplementary header providing flight and aircraft context from
/// `<M633SupplementaryHeader>` (or the LTD variant `<M633LTDSupplementaryHeader>`).
public struct SupplementaryHeader: Sendable, Equatable {
    /// Flight identification and route.
    public let flight: ARINCHeaderFlight

    /// Aircraft identification.
    public let aircraft: ARINCHeaderAircraft

    /// Optional FlightKeys key — `<FlightKeyIdentifier>` UUID, when present.
    ///
    /// Per m633headers.xsd this is an optional child of the supplementary header;
    /// it correlates the message with a FlightKeys flight record. Nil when absent.
    public let flightKeyIdentifier: String?

    public init(flight: ARINCHeaderFlight = ARINCHeaderFlight(),
                aircraft: ARINCHeaderAircraft = ARINCHeaderAircraft(),
                flightKeyIdentifier: String? = nil) {
        self.flight = flight
        self.aircraft = aircraft
        self.flightKeyIdentifier = flightKeyIdentifier
    }
}

// MARK: - Airport

/// Airport identification within header context.
public struct ARINCHeaderAirport: Sendable, Equatable {
    /// 4-letter ICAO code (e.g., "KMIA").
    public let icaoCode: String

    /// 3-letter IATA code (e.g., "MIA"), if available.
    public let iataCode: String?

    /// Airport name (e.g., "MIAMI").
    public let name: String?

    public init(icaoCode: String = "", iataCode: String? = nil, name: String? = nil) {
        self.icaoCode = icaoCode
        self.iataCode = iataCode
        self.name = name
    }
}

// MARK: - Aircraft

/// Aircraft identification within header context.
public struct ARINCHeaderAircraft: Sendable, Equatable {
    /// Aircraft registration (e.g., "N408MC").
    public let registration: String

    /// ICAO aircraft type code (e.g., "B744").
    public let aircraftType: String?

    /// Airline-specific sub type including engine (e.g., "B747 8F GENX-2B67P").
    public let engineType: String?

    public init(registration: String = "", aircraftType: String? = nil, engineType: String? = nil) {
        self.registration = registration
        self.aircraftType = aircraftType
        self.engineType = engineType
    }
}

// MARK: - Flight

/// Flight identification within header context.
public struct ARINCHeaderFlight: Sendable, Equatable {
    /// Airline IATA code (e.g., "5Y").
    public let airlineCode: String

    /// Flight number string (e.g., "554").
    public let flightNumber: String

    /// Flight identifier (e.g., "GTI554").
    public let flightIdentifier: String?

    /// Commercial flight number (e.g., "5Y554").
    public let commercialFlightNumber: String?

    /// Departure airport.
    public let departure: ARINCHeaderAirport

    /// Arrival airport.
    public let arrival: ARINCHeaderAirport

    /// Scheduled departure time (ISO 8601).
    public let scheduledDepartureTime: String?

    /// Flight origin date (e.g., "2026-03-04").
    public let flightOriginDate: String?

    public init(airlineCode: String = "", flightNumber: String = "",
                flightIdentifier: String? = nil, commercialFlightNumber: String? = nil,
                departure: ARINCHeaderAirport = ARINCHeaderAirport(),
                arrival: ARINCHeaderAirport = ARINCHeaderAirport(),
                scheduledDepartureTime: String? = nil, flightOriginDate: String? = nil) {
        self.airlineCode = airlineCode
        self.flightNumber = flightNumber
        self.flightIdentifier = flightIdentifier
        self.commercialFlightNumber = commercialFlightNumber
        self.departure = departure
        self.arrival = arrival
        self.scheduledDepartureTime = scheduledDepartureTime
        self.flightOriginDate = flightOriginDate
    }
}
