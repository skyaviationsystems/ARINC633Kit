// ETOPSSummary.swift
// ARINC633Kit
//
// ETOPS critical fuel positions with CriticalPosition and SuitableAirport sub-models.

import Foundation

/// ETOPS (Extended Twin Operations) summary with critical fuel positions.
public struct ETOPSSummary: Sendable, Equatable {
    /// ETOPS rule time from ruleTime attribute (e.g., PT03H00M = 180 min).
    public var ruleTime: ARINC633Duration?

    /// ETOPS threshold/border time (`ETOPSSummary/@borderTime`, xs:duration) — the time
    /// to the ETOPS entry point. SAFETY-RELEVANT: present in all official samples.
    public var borderTime: ARINC633Duration?

    /// Whether this flight is an ETOPS flight (from NonStandardFlightPlanningType ETOPS element).
    public var isETOPS: Bool

    /// ETOPS entry waypoint name.
    public var entryWaypoint: String?

    /// ETOPS exit waypoint name.
    public var exitWaypoint: String?

    /// ETOPS critical fuel waypoint.
    public var criticalFuelWaypoint: String?

    /// Critical fuel at the waypoint.
    public var criticalFuel: ARINCWeight?

    /// Maximum diversion time.
    public var maxDiversionTime: ARINC633Duration?

    /// ETOPS adequate airport ICAO codes (legacy summary list).
    public var adequateAirports: [String]

    /// Critical positions with detailed diversion data.
    public var criticalPositions: [CriticalPosition]

    public init() {
        self.isETOPS = false
        self.adequateAirports = []
        self.criticalPositions = []
    }
}

/// A critical position (ETP) within an ETOPS corridor.
public struct CriticalPosition: Sendable, Equatable {
    /// Position name (e.g., "ETP1", "ETOPS_ENTRY").
    public var positionName: String?

    /// Sequence ID for this critical position.
    public var sequenceId: Int?

    /// Critical position type (e.g., "COVERAGE_ENTRY", "ETOPS_ENTRY", "ETOPS_ETP").
    public var criticalPositionType: String?

    /// Latitude in raw ARINC arc-seconds format.
    public var latitude: Double?

    /// Longitude in raw ARINC arc-seconds format.
    public var longitude: Double?

    /// Critical time at this position.
    public var criticalTime: ARINC633Duration?

    /// Fuel on board at this position.
    public var fuelOnBoard: ARINCWeight?

    /// Altitude at this position in feet.
    public var altitude: ARINCAltitude?

    /// Scenario condition (e.g., "decompression", "one engine out", "two engines out").
    public var condition: String?

    /// Suitable (escape) airports reachable from this position.
    public var suitableAirports: [ETOPSSuitableAirport]

    /// Adequate (ETOPS approved) airports at this position.
    public var adequateAirports: [AdequateAirport]

    public init() {
        self.suitableAirports = []
        self.adequateAirports = []
    }
}

/// A suitable airport reachable from a critical position during ETOPS diversion.
public struct ETOPSSuitableAirport: Sendable, Equatable {
    /// Airport ICAO code.
    public var airportICAO: String?

    /// Airport IATA code.
    public var airportIATA: String?

    /// Airport name.
    public var airportName: String?

    /// Relative location (e.g., "ahead", "behind").
    public var relativeLocation: String?

    /// Whether this is the critical fuel en-route alternate.
    public var isCriticalFuelEnRouteAlternate: Bool

    /// Remaining flight time to this airport.
    public var remainingFlightTime: ARINC633Duration?

    /// Remaining air distance to this airport.
    public var remainingAirDistance: ARINCDistance?

    /// Remaining ground distance to this airport.
    public var remainingGroundDistance: ARINCDistance?

    /// Diversion altitude in feet.
    public var altitude: ARINCDistance?

    /// Minimum safe altitude / MORA in feet.
    public var minimumSafeAltitude: ARINCDistance?

    /// Trip fuel to reach this airport.
    public var tripFuel: ARINCWeight?

    /// Final reserve fuel.
    public var finalReserve: ARINCWeight?

    /// Icing condition fuel adder.
    public var icingConditionFuel: ARINCWeight?

    /// Critical fuel (total minimum required).
    public var criticalFuel: ARINCWeight?

    /// Average wind component on diversion route.
    public var averageWindComponent: ARINCSpeed?

    /// Average temperature on diversion route.
    public var averageTemperature: ARINCTemperature?

    /// Maximum terrain elevation on diversion route.
    public var maximumTerrainElevation: ARINCAltitude?

    /// Minimum vertical clearance above terrain on diversion route.
    public var minimumVerticalClearance: ARINCAltitude?

    /// Safe altitudes from the diversion route terrain avoidance.
    public var safeAltitudes: [SafeAltitude]

    /// Airport function (e.g., "ETOPSAdequateAirport", "EscapeAirport").
    public var airportFunction: String?

    public init() {
        self.isCriticalFuelEnRouteAlternate = false
        self.safeAltitudes = []
    }
}

/// Distinguishes adequate airports (ETOPS) vs suitable (escape) airports in critical positions.
public struct AdequateAirport: Sendable, Equatable {
    /// Airport ICAO code.
    public var airportICAO: String?

    /// Airport IATA code.
    public var airportIATA: String?

    /// Airport name.
    public var airportName: String?

    /// Relative location ("ahead" or "behind").
    public var relativeLocation: String?

    /// Whether approved as critical fuel en-route alternate.
    public var isCriticalFuelEnRouteAlternate: Bool

    /// Remaining flight time to this airport.
    public var remainingFlightTime: ARINC633Duration?

    /// Remaining air distance.
    public var remainingAirDistance: ARINCDistance?

    /// Remaining ground distance.
    public var remainingGroundDistance: ARINCDistance?

    /// Diversion altitude in feet.
    public var altitude: ARINCDistance?

    /// Trip fuel to reach this airport.
    public var tripFuel: ARINCWeight?

    /// Final reserve fuel.
    public var finalReserve: ARINCWeight?

    /// Icing condition fuel adder.
    public var icingConditionFuel: ARINCWeight?

    /// Critical fuel total.
    public var criticalFuel: ARINCWeight?

    /// Average wind component.
    public var averageWindComponent: ARINCSpeed?

    /// Maximum terrain elevation.
    public var maximumTerrainElevation: ARINCAltitude?

    /// Minimum vertical clearance.
    public var minimumVerticalClearance: ARINCAltitude?

    /// Safe altitudes from diversion route.
    public var safeAltitudes: [SafeAltitude]

    public init() {
        self.isCriticalFuelEnRouteAlternate = false
        self.safeAltitudes = []
    }
}
