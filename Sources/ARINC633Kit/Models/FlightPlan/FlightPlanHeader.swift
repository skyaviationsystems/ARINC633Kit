// FlightPlanHeader.swift
// ARINC633Kit
//
// Route, performance, MEL/CDL information from <FlightPlanHeader>.

import Foundation

/// Route, performance, and supplementary information from the FlightPlanHeader section.
public struct FlightPlanHeader: Sendable, Equatable {
    /// Author/dispatcher who created the flight plan.
    public var authorName: String?

    /// Email of the author/dispatcher.
    public var authorEmail: String?

    /// Performance factor applied to fuel calculations.
    public var performanceFactor: Double?

    /// Average fuel flow rate.
    public var averageFuelFlow: ARINCFlow?

    /// Holding fuel flow rate.
    public var holdingFuelFlow: ARINCFlow?

    /// FMS route name (e.g., "KMIAPANC02").
    public var fmsRouteName: String?

    /// Route name/variant (e.g., "R2").
    public var routeName: String?

    /// Optimization type (e.g., "LC" for least cost, "LF" for least fuel).
    public var optimization: String?

    /// Average wind direction.
    public var averageWindDirection: Double?

    /// Average wind speed.
    public var averageWindSpeed: ARINCSpeed?

    /// Average wind component (positive = tailwind, negative = headwind).
    public var averageWindComponent: ARINCSpeed?

    /// Average enroute temperature.
    public var averageTemperature: ARINCTemperature?

    /// Average ISA deviation.
    public var averageISADeviation: ARINCTemperature?

    /// Initial cruise altitude.
    public var initialAltitude: ARINCAltitude?

    /// Climb procedure description (e.g., "250/316/M84").
    public var climbProcedure: String?

    /// Cruise procedure description (e.g., "CI035").
    public var cruiseProcedure: String?

    /// Cost index value.
    public var costIndex: Int?

    /// Descent procedure description (e.g., "M84/267/250").
    public var descentProcedure: String?

    /// Full textual route description.
    public var routeDescription: String?

    /// Total ground distance.
    public var groundDistance: ARINCDistance?

    /// Total air distance.
    public var airDistance: ARINCDistance?

    /// Great circle distance.
    public var greatCircleDistance: ARINCDistance?

    /// Total distance (same as groundDistance if both provided).
    public var totalDistance: ARINCDistance?

    /// MEL/CDL items.
    public var melCdlItems: [MELCDLItem]

    /// Contingency policy name (e.g., "10 PCT TIME").
    public var contingencyPolicy: String?

    /// Cost information from 633-5 CostInformation element.
    public var costInformation: CostInformation?

    /// Environmental impact factors from 633-5 EnvironmentalImpactFactors element.
    public var environmentalImpact: EnvironmentalImpact?

    /// Vertical profile description (e.g., "FL320 TXO/FL340 49N30/FL360").
    public var verticalProfileDescription: String?

    /// Engine identifier (e.g., "CF6-80C2-B1F").
    public var engineId: String?

    /// Dispatch office identifier from AuthorContact.
    public var dispatchOffice: String?

    /// AIRAC cycle validity from NavDataValidity element.
    public var navDataValidity: NavDataValidity?

    /// Upper air data forecast period start (ISO 8601).
    public var upperAirDataForecastStart: String?

    /// Upper air data forecast period end (ISO 8601).
    public var upperAirDataForecastEnd: String?

    /// Regulation policies applied to this flight plan.
    public var regulationPolicies: [String]

    public init() {
        self.melCdlItems = []
        self.regulationPolicies = []
    }
}

/// AIRAC cycle validity period from NavDataValidity element.
public struct NavDataValidity: Sendable, Equatable {
    /// AIRAC cycle identifier (e.g., "2603").
    public var airacCycleId: String?

    /// AIRAC cycle start date (e.g., "2026-03-19").
    public var airacCycleStart: String?

    /// AIRAC cycle end date (e.g., "2026-04-15").
    public var airacCycleEnd: String?

    public init(airacCycleId: String? = nil, airacCycleStart: String? = nil, airacCycleEnd: String? = nil) {
        self.airacCycleId = airacCycleId
        self.airacCycleStart = airacCycleStart
        self.airacCycleEnd = airacCycleEnd
    }
}

/// Cost breakdown from 633-5 CostInformation element inside FlightPlanHeader.
public struct CostInformation: Sendable, Equatable {
    /// Currency code (e.g., "USD", "EUR").
    public let currency: String

    /// Total cost of the flight.
    public let totalCost: Double?

    /// Fuel cost component.
    public let fuelCost: Double?

    /// Time-related cost component.
    public let timeCost: Double?

    /// Delay cost component.
    public let delayCost: Double?

    /// Enroute navigation/airspace charges.
    public let enrouteCharges: Double?

    /// Other cost items keyed by qualifier (e.g., "EngineCycleCost").
    public let otherCosts: [OtherCost]

    public init(currency: String = "", totalCost: Double? = nil, fuelCost: Double? = nil,
                timeCost: Double? = nil, delayCost: Double? = nil, enrouteCharges: Double? = nil,
                otherCosts: [OtherCost] = []) {
        self.currency = currency
        self.totalCost = totalCost
        self.fuelCost = fuelCost
        self.timeCost = timeCost
        self.delayCost = delayCost
        self.enrouteCharges = enrouteCharges
        self.otherCosts = otherCosts
    }
}

/// A single OtherCost entry with a qualifier label and value.
public struct OtherCost: Sendable, Equatable {
    /// Qualifier describing the cost type (e.g., "EngineCycleCost").
    public let qualifier: String

    /// Monetary value.
    public let value: Double

    public init(qualifier: String, value: Double) {
        self.qualifier = qualifier
        self.value = value
    }
}

/// Environmental impact factors from 633-5 EnvironmentalImpactFactors element.
public struct EnvironmentalImpact: Sendable, Equatable {
    /// CO2 emissions in tonnes.
    public let co2Tonnes: Double?

    /// Energy factor in megajoules (MJ).
    public let energyFactor: Double?

    public init(co2Tonnes: Double? = nil, energyFactor: Double? = nil) {
        self.co2Tonnes = co2Tonnes
        self.energyFactor = energyFactor
    }
}

/// Minimum Equipment List / Configuration Deviation List item.
public struct MELCDLItem: Sendable, Equatable {
    /// Type: "MEL" or "CDL".
    public let type: String

    /// Reference identifier (e.g., "33-45-01").
    public let referenceId: String

    /// Title/description (e.g., "LOGO LIGHTS").
    public let title: String

    /// Additional remarks text.
    public let remark: String?

    /// Whether the MEL/CDL item has been handled/acknowledged (633-5).
    public let handled: Bool

    /// Operational effects of this MEL/CDL item (633-5).
    public let effects: [MELEffect]

    public init(type: String, referenceId: String, title: String, remark: String? = nil,
                handled: Bool = false, effects: [MELEffect] = []) {
        self.type = type
        self.referenceId = referenceId
        self.title = title
        self.remark = remark
        self.handled = handled
        self.effects = effects
    }
}

/// An operational effect of a MEL/CDL item (e.g., latitude limitation, equipment suppression).
public struct MELEffect: Sendable, Equatable {
    /// Effect identifier (e.g., "Latitude limiation (N)", "RCP unavailable").
    public let identifier: String

    /// Optional numeric or string value (e.g., "78" for latitude limit).
    public let value: String?

    /// Human-readable description of the effect.
    public let description: String

    public init(identifier: String, value: String? = nil, description: String) {
        self.identifier = identifier
        self.value = value
        self.description = description
    }
}
