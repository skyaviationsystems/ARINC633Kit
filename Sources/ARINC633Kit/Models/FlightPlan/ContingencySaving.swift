// ContingencySaving.swift
// ARINC633Kit
//
// Contingency saving/redispatch route from <ContingencySavingHeader>.
// Contains its OWN fuelHeader + waypoints (separate from main route).

import Foundation

/// Contingency saving (reclearance/redispatch) route data.
///
/// This section contains its own separate fuel header and waypoints,
/// distinct from the main route data.
public struct ContingencySaving: Sendable, Equatable {
    /// Decision point waypoint name.
    public var decisionPointName: String?

    /// Time over the decision point (ISO 8601 datetime).
    public var timeOverDecisionPoint: String?

    /// Cumulated flight time at decision point.
    public var cumulatedFlightTime: ARINC633Duration?

    /// Contingency saving airport ICAO code.
    public var airportICAO: String?

    /// Contingency saving airport name.
    public var airportName: String?

    /// Airport function.
    public var airportFunction: String?

    /// Fuel required to reach the arrival airport from decision point.
    public var fuelRequiredToArrival: ARINCWeight?

    /// Fuel required to reach the contingency saving airport.
    public var fuelRequiredToContingencySavingAirport: ARINCWeight?

    /// Contingency saving route's own fuel header.
    public var fuelHeader: FuelHeader?

    /// Contingency saving route waypoints (separate from main route).
    public var waypoints: [Waypoint]

    public init() {
        self.waypoints = []
    }
}
