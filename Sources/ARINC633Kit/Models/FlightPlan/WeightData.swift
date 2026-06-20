// WeightData.swift
// ARINC633Kit
//
// Convenience weight summary model aggregating key weight values from WeightHeader.

import Foundation

/// Convenience weight data model providing direct access to key weight values.
///
/// This struct mirrors the data in WeightHeader but provides direct (non-EstimatedActual)
/// access for use cases that only need the estimated values.
public struct WeightData: Sendable, Equatable {
    /// Dry operating weight.
    public var dryOperatingWeight: ARINCWeight?

    /// Zero fuel weight.
    public var zeroFuelWeight: ARINCWeight?

    /// Basic weight (within DOW).
    public var basicWeight: ARINCWeight?

    /// Cargo load weight.
    public var cargoLoad: ARINCWeight?

    /// Passenger load weight.
    public var paxLoad: ARINCWeight?

    /// Taxi weight.
    public var taxiWeight: ARINCWeight?

    /// Takeoff weight.
    public var takeoffWeight: ARINCWeight?

    /// Landing weight.
    public var landingWeight: ARINCWeight?

    /// Landing fuel (remaining fuel at destination).
    public var landingFuel: ARINCWeight?

    /// Maximum fuel weight (tank capacity limit).
    public var maximumFuelWeight: ARINCWeight?

    /// Tank volume in the unit provided by the XML.
    public var tankVolume: ARINCVolume?

    /// ZFW or TOW structural limit (whichever applies contextually).
    public var structuralLimit: ARINCWeight?

    /// TOW or LDW operational limit.
    public var operationalLimit: ARINCWeight?

    /// Departure fuel density.
    public var departureFuelDensity: Double?

    public init() {}
}
