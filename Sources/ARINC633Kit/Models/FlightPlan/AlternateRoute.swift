// AlternateRoute.swift
// ARINC633Kit
//
// Alternate airport route with its own waypoints.

import Foundation

/// An alternate route to a diversion airport.
public struct AlternateRoute: Sendable, Equatable {
    /// Waypoints along this alternate route.
    public var waypoints: [Waypoint]

    /// Alternate airport ICAO code.
    public var airportICAO: String?

    /// Alternate airport name.
    public var airportName: String?

    /// Airport function (e.g., PrimaryArrivalAlternateAirport).
    public var airportFunction: String?

    /// Route information for the alternate.
    public var fmsRouteName: String?

    /// Average wind component.
    public var averageWindComponent: ARINCSpeed?

    /// Average temperature.
    public var averageTemperature: ARINCTemperature?

    /// Average ISA deviation.
    public var averageISADeviation: ARINCTemperature?

    /// Initial altitude for alternate.
    public var initialAltitude: ARINCAltitude?

    /// Route description text.
    public var routeDescription: String?

    /// Ground distance to alternate.
    public var groundDistance: ARINCDistance?

    /// Air distance to alternate.
    public var airDistance: ARINCDistance?

    public init() {
        self.waypoints = []
    }
}
