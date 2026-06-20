// WeightHeader.swift
// ARINC633Kit
//
// ZFW, TOW, LDW weight information from <WeightHeader>.

import Foundation

/// Weight header containing all key weight values with operational/structural limits.
public struct WeightHeader: Sendable, Equatable {
    /// Dry operating weight.
    public var dryOperatingWeight: EstimatedActual<ARINCWeight>

    /// Basic weight component within dry operating weight.
    public var basicWeight: ARINCWeight?

    /// Cargo load weight.
    public var cargoLoad: ARINCWeight?

    /// Passenger load weight.
    public var paxLoad: ARINCWeight?

    /// Payload/load weight (total).
    public var load: EstimatedActual<ARINCWeight>

    /// Zero fuel weight.
    public var zeroFuelWeight: EstimatedActual<ARINCWeight>

    /// ZFW operational limit.
    public var zfwOperationalLimit: ARINCWeight?

    /// ZFW structural limit.
    public var zfwStructuralLimit: ARINCWeight?

    /// Taxi weight.
    public var taxiWeight: EstimatedActual<ARINCWeight>

    /// Taxi weight structural limit.
    public var taxiWeightStructuralLimit: ARINCWeight?

    /// Takeoff weight.
    public var takeoffWeight: EstimatedActual<ARINCWeight>

    /// TOW operational limit.
    public var towOperationalLimit: ARINCWeight?

    /// TOW structural limit.
    public var towStructuralLimit: ARINCWeight?

    /// Limiting reason for TOW (e.g., "TAKEOFF_AND_LANDING_PERFORMANCE").
    public var towLimitReason: String?

    /// Landing weight.
    public var landingWeight: EstimatedActual<ARINCWeight>

    /// LDW operational limit.
    public var ldwOperationalLimit: ARINCWeight?

    /// LDW structural limit.
    public var ldwStructuralLimit: ARINCWeight?

    /// Limiting reason for LDW.
    public var ldwLimitReason: String?

    public init() {
        self.dryOperatingWeight = EstimatedActual()
        self.load = EstimatedActual()
        self.zeroFuelWeight = EstimatedActual()
        self.taxiWeight = EstimatedActual()
        self.takeoffWeight = EstimatedActual()
        self.landingWeight = EstimatedActual()
    }
}
