// FuelHeader.swift
// ARINC633Kit
//
// All fuel categories from <FuelHeader>.

import Foundation

/// All fuel categories for the flight plan.
public struct FuelHeader: Sendable, Equatable {
    /// Trip fuel (fuel burn for the planned route).
    public var tripFuel: ARINCWeight?

    /// Trip fuel duration.
    public var tripDuration: ARINC633Duration?

    /// Contingency fuel.
    public var contingencyFuel: ARINCWeight?

    /// Contingency fuel duration.
    public var contingencyDuration: ARINC633Duration?

    /// Contingency policy name (e.g., "10 PCT TIME").
    public var contingencyPolicy: String?

    /// Alternate fuel entries (may be multiple alternates).
    public var alternateFuels: [AlternateFuelEntry]

    /// Final reserve fuel.
    public var reserveFuel: ARINCWeight?

    /// Final reserve duration.
    public var reserveDuration: ARINC633Duration?

    /// Additional fuel items (PCF, Redispatch, MinLandingFuel, etc.).
    public var additionalFuels: [AdditionalFuelItem]

    /// Extra fuel items (DispatchDefined, EconomicTankering, Other, etc.).
    public var extraFuels: [ExtraFuelItem]

    /// Takeoff fuel.
    public var takeoffFuel: ARINCWeight?

    /// Takeoff fuel duration.
    public var takeoffDuration: ARINC633Duration?

    /// Taxi fuel.
    public var taxiFuel: ARINCWeight?

    /// Taxi fuel duration.
    public var taxiDuration: ARINC633Duration?

    /// Block fuel (total fuel loaded).
    public var blockFuel: ARINCWeight?

    /// Block fuel duration.
    public var blockDuration: ARINC633Duration?

    /// Arrival fuel (fuel remaining at destination).
    public var arrivalFuel: ARINCWeight?

    /// Maximum possible extra fuel weight.
    public var maxExtraFuelWeight: ARINCWeight?

    /// Tank volume for PossibleExtraFuel.
    public var tankVolume: ARINCVolume?

    /// Minimum block fuel.
    public var minimumBlockFuel: ARINCWeight?

    /// Minimum block fuel duration.
    public var minimumBlockDuration: ARINC633Duration?

    /// Minimum takeoff fuel.
    public var minimumTakeoffFuel: ARINCWeight?

    /// Minimum takeoff fuel duration.
    public var minimumTakeoffDuration: ARINC633Duration?

    /// Landing fuel (fuel remaining at destination).
    public var landingFuel: ARINCWeight?

    /// Landing fuel duration.
    public var landingDuration: ARINC633Duration?

    /// Informational fuel entries (display-only, non-planning fuels).
    public var informationalFuels: [InformationalFuel]

    /// Tankering advice data from TankeringInfo element.
    public var tankeringAdvice: TankeringData?

    /// Loadable extra fuel weight from `PossibleExtraFuel/PossibleExtra` (a Weight).
    ///
    /// This is the fuel that could additionally be loaded — distinct from
    /// `maxExtraFuelWeight`, which comes from `PossibleExtraFuel/MaximumFuelWeight/Weight`
    /// (the tank capacity). Previously this field was wrongly filled from MaximumFuelWeight.
    public var possibleExtraFuelWeight: ARINCWeight?

    /// Fuel density from `PossibleExtraFuel/MaximumFuelWeight/Density` (e.g. g/cm3), when present.
    public var maximumFuelDensity: ARINCDensity?

    /// `ETOPSFuel` line (FuelHeaderLineBasicType: EstimatedWeight + Duration).
    public var etopsFuel: ARINCWeight?

    /// `ETOPSFuel` duration.
    public var etopsDuration: ARINC633Duration?

    /// `NoAlternateFinalReserve` line (FuelHeaderLineBasicType): final reserve when planned with no alternate.
    public var noAlternateFinalReserveFuel: ARINCWeight?

    /// `NoAlternateFinalReserve` duration.
    public var noAlternateFinalReserveDuration: ARINC633Duration?

    /// `NoAlternate` flag — flight plan computed without an alternate fuel airport.
    public var noAlternate: Bool?

    /// `ContingencySavingsAdditionalFuel` line (FuelHeaderLineBasicType).
    public var contingencySavingsAdditionalFuel: ARINCWeight?

    /// `ContingencySavingsAdditionalFuel` duration.
    public var contingencySavingsAdditionalDuration: ARINC633Duration?

    /// `CaptainProtectedExtraFuel` line (FuelHeaderLineReasonType) — captain extra fuel that impacts trip fuel.
    public var captainProtectedExtraFuel: ARINCWeight?

    /// `CaptainProtectedExtraFuel` duration.
    public var captainProtectedExtraDuration: ARINC633Duration?

    /// `CaptainUnprotectedExtraFuel` line (FuelHeaderLineReasonType).
    public var captainUnprotectedExtraFuel: ARINCWeight?

    /// `CaptainUnprotectedExtraFuel` duration.
    public var captainUnprotectedExtraDuration: ARINC633Duration?

    /// `BlockFuel/FuelOnBoardAfterRefueling` — fuel in tank after refueling.
    public var fuelOnBoardAfterRefueling: ARINCWeight?

    /// `ContingencyFuel/ContingencyPolicy/EnrouteAlternateAirport` ICAO code, when present.
    public var contingencyEnrouteAlternateAirportICAO: String?

    /// Remarks within fuel header.
    public var remarks: [String]

    public init() {
        self.alternateFuels = []
        self.additionalFuels = []
        self.extraFuels = []
        self.informationalFuels = []
        self.remarks = []
    }
}

/// An informational fuel entry (display-only, not used in planning calculations).
public struct InformationalFuel: Sendable, Equatable {
    /// Reason/category label (e.g., "REMF BALST", "ROUND").
    public let reason: String

    /// Display label.
    public let label: String?

    /// Fuel weight.
    public let weight: ARINCWeight?

    /// Duration.
    public let duration: ARINC633Duration?

    public init(reason: String, label: String? = nil, weight: ARINCWeight? = nil, duration: ARINC633Duration? = nil) {
        self.reason = reason
        self.label = label
        self.weight = weight
        self.duration = duration
    }
}

/// Tankering economics advice from TankeringInfo section.
public struct TankeringData: Sendable, Equatable {
    /// Recommended tankering fuel weight.
    public var tankeringWeight: ARINCWeight?

    /// Estimated financial profit from tankering.
    public var tankeringProfit: Double?

    public init(tankeringWeight: ARINCWeight? = nil, tankeringProfit: Double? = nil) {
        self.tankeringWeight = tankeringWeight
        self.tankeringProfit = tankeringProfit
    }
}

/// A single alternate fuel entry.
public struct AlternateFuelEntry: Sendable, Equatable {
    /// Estimated fuel weight for this alternate.
    public var weight: ARINCWeight?

    /// Duration to alternate.
    public var duration: ARINC633Duration?

    /// Alternate airport ICAO code.
    public var airportICAO: String?

    /// Alternate airport name.
    public var airportName: String?

    /// Alternate airport function.
    public var airportFunction: String?

    /// Final reserve associated with this alternate.
    public var finalReserveWeight: ARINCWeight?

    /// Final reserve duration.
    public var finalReserveDuration: ARINC633Duration?

    /// Sequence number.
    public var sequence: Int?

    public init() {}
}

/// Additional fuel item (e.g., PCF, Redispatch, MinLandingFuel).
public struct AdditionalFuelItem: Sendable, Equatable {
    /// Reason category for the additional fuel.
    public let reason: FuelCategory

    /// Fuel weight.
    public let weight: ARINCWeight?

    /// Duration.
    public let duration: ARINC633Duration?

    public init(reason: FuelCategory, weight: ARINCWeight? = nil, duration: ARINC633Duration? = nil) {
        self.reason = reason
        self.weight = weight
        self.duration = duration
    }
}

/// Extra fuel item (e.g., DispatchDefined, EconomicTankering).
public struct ExtraFuelItem: Sendable, Equatable {
    /// Reason for extra fuel.
    public let reason: FuelCategory

    /// Fuel weight.
    public let weight: ARINCWeight?

    /// Duration.
    public let duration: ARINC633Duration?

    /// Whether this extra fuel came from `ProtectedExtraFuels` (`true`) vs
    /// `UnprotectedExtraFuels` (`false`). `nil` when the item was outside either
    /// wrapper (legacy `ExtraFuel`). Protected extra fuel is preserved through
    /// reclearance/redispatch fuel optimization; unprotected may be consumed.
    public let protected: Bool?

    public init(reason: FuelCategory, weight: ARINCWeight? = nil, duration: ARINC633Duration? = nil, protected: Bool? = nil) {
        self.reason = reason
        self.weight = weight
        self.duration = duration
        self.protected = protected
    }
}
