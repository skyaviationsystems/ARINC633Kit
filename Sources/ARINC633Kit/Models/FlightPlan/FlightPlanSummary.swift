// FlightPlanSummary.swift
// ARINC633Kit
//
// OOOI times and flight time totals from <FlightPlanSummary>.

import Foundation

/// Flight plan summary with OOOI times and totals.
public struct FlightPlanSummary: Sendable, Equatable {
    /// Scheduled time of arrival (ISO 8601).
    public var scheduledTimeOfArrival: String?

    /// Out time (gate departure).
    public var outTime: String?

    /// Off time (wheels up).
    public var offTime: String?

    /// On time (wheels down).
    public var onTime: String?

    /// In time (gate arrival).
    public var inTime: String?

    /// Total block time.
    public var blockTime: ARINC633Duration?

    /// Taxi out time.
    public var taxiOutTime: ARINC633Duration?

    /// Flight time (wheels up to wheels down).
    public var flightTime: ARINC633Duration?

    /// Taxi in time.
    public var taxiInTime: ARINC633Duration?

    public init() {}
}
