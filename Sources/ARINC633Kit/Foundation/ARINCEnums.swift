// ARINCEnums.swift
// ARINC633Kit
//
// All ARINC 633 enumeration types with .unknown(String) fallback case
// for extensibility per spec guidance. Values sourced from m633common.xsd.

import Foundation

// MARK: - Waypoint Function

/// Function/purpose of a waypoint in the flight plan.
public enum WaypointFunction: Sendable, Equatable {
    case departureAirport
    case arrivalAirport
    case enroute
    case topOfClimb
    case topOfDescent
    case airspaceBoundary
    case contingencySavingsDecisionWaypoint
    case contingencySavingAirport
    case etopsAdequateAirport
    case departureAlternateAirport
    case arrivalAlternateAirport
    case enRouteAlternateAirport
    case escapeAirport
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "DepartureAirport": self = .departureAirport
        case "ArrivalAirport": self = .arrivalAirport
        case "Enroute": self = .enroute
        case "TopOfClimb": self = .topOfClimb
        case "TopOfDescent": self = .topOfDescent
        case "AirspaceBoundary": self = .airspaceBoundary
        case "ContingencySavingsDecisionWaypoint": self = .contingencySavingsDecisionWaypoint
        case "ContingencySavingAirport": self = .contingencySavingAirport
        case "ETOPSAdequateAirport": self = .etopsAdequateAirport
        case "DepartureAlternateAirport": self = .departureAlternateAirport
        case "ArrivalAlternateAirport": self = .arrivalAlternateAirport
        case "EnRouteAlternateAirport": self = .enRouteAlternateAirport
        case "EscapeAirport": self = .escapeAirport
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Fuel Category

/// Category/type of additional fuel.
public enum FuelCategory: Sendable, Equatable {
    case airTrafficControl
    case ballastFuel
    case deviation
    case dispatchDefined
    case fuelOnBoard
    case minimumLandingWeight
    case minimumReserve
    case operation
    case specialHolding
    case tankering
    case terrainClearance
    case weather
    case airportWeather
    case regionWeather
    case mandatoryTankering
    case economicTankering
    case additional
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "AirTrafficControl": self = .airTrafficControl
        case "BallastFuel": self = .ballastFuel
        case "Deviation": self = .deviation
        case "DispatchDefined": self = .dispatchDefined
        case "FuelOnBoard": self = .fuelOnBoard
        case "MinimumLandingWeight": self = .minimumLandingWeight
        case "MinimumReserve": self = .minimumReserve
        case "Operation": self = .operation
        case "SpecialHolding": self = .specialHolding
        case "Tankering": self = .tankering
        case "TerrainClearance": self = .terrainClearance
        case "Weather": self = .weather
        case "AirportWeather": self = .airportWeather
        case "RegionWeather": self = .regionWeather
        case "MandatoryTankering": self = .mandatoryTankering
        case "EconomicTankering": self = .economicTankering
        case "Additional": self = .additional
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Weight Category

/// Category for weight limits (operational vs structural).
public enum WeightCategory: Sendable, Equatable {
    case operational
    case structural
    case performance
    case regulatory
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Operational": self = .operational
        case "Structural": self = .structural
        case "Performance": self = .performance
        case "Regulatory": self = .regulatory
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Flight Phase

/// Phase of flight.
public enum FlightPhase: Sendable, Equatable {
    case taxi
    case takeoff
    case climb
    case cruise
    case descent
    case approach
    case landing
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Taxi": self = .taxi
        case "Takeoff": self = .takeoff
        case "Climb": self = .climb
        case "Cruise": self = .cruise
        case "Descent": self = .descent
        case "Approach": self = .approach
        case "Landing": self = .landing
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Altitude Reference

/// Reference datum for altitude values.
public enum AltitudeReference: Sendable, Equatable {
    case msl
    case agl
    case standardPressure
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "MSL": self = .msl
        case "AGL": self = .agl
        case "StandardPressure": self = .standardPressure
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Speed Type

/// Type of speed measurement.
public enum SpeedType: Sendable, Equatable {
    case indicated
    case trueAirspeed
    case groundSpeed
    case mach
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Indicated", "IAS": self = .indicated
        case "TrueAirspeed", "TAS": self = .trueAirspeed
        case "GroundSpeed", "GS": self = .groundSpeed
        case "Mach": self = .mach
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Track Type

/// Type of track (true vs magnetic).
public enum TrackType: Sendable, Equatable {
    case trueTrack
    case magnetic
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "true": self = .trueTrack
        case "magnetic": self = .magnetic
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Wind Direction

/// Wind direction relative to flight path.
public enum WindDirection: Sendable, Equatable {
    case headwind
    case tailwind
    case crosswind
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Headwind": self = .headwind
        case "Tailwind": self = .tailwind
        case "Crosswind": self = .crosswind
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Cloud Cover

/// Cloud cover amount.
public enum CloudCover: Sendable, Equatable {
    case skc
    case few
    case sct
    case bkn
    case ovc
    case cavok
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue.uppercased() {
        case "SKC": self = .skc
        case "FEW": self = .few
        case "SCT": self = .sct
        case "BKN": self = .bkn
        case "OVC": self = .ovc
        case "CAVOK": self = .cavok
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Weather Phenomenon

/// Significant weather phenomena.
public enum WeatherPhenomenon: Sendable, Equatable {
    case rain
    case snow
    case drizzle
    case fog
    case mist
    case haze
    case thunderstorm
    case freezingRain
    case freezingDrizzle
    case ice
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "RA", "Rain": self = .rain
        case "SN", "Snow": self = .snow
        case "DZ", "Drizzle": self = .drizzle
        case "FG", "Fog": self = .fog
        case "BR", "Mist": self = .mist
        case "HZ", "Haze": self = .haze
        case "TS", "Thunderstorm": self = .thunderstorm
        case "FZRA", "FreezingRain": self = .freezingRain
        case "FZDZ", "FreezingDrizzle": self = .freezingDrizzle
        case "IC", "Ice": self = .ice
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Crew Rank

/// Crew member rank/position.
public enum CrewRank: Sendable, Equatable {
    case captain
    case firstOfficer
    case seniorFirstOfficer
    case secondOfficer
    case reliefPilot
    case flightEngineer
    case loadmaster
    case purser
    case cabinAttendant
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Captain", "CPT", "CP", "PIC": self = .captain
        case "FirstOfficer", "FO", "SIC": self = .firstOfficer
        case "SeniorFirstOfficer", "SF": self = .seniorFirstOfficer
        case "SecondOfficer", "SO": self = .secondOfficer
        case "ReliefPilot", "RP", "IRO": self = .reliefPilot
        case "FlightEngineer", "FE": self = .flightEngineer
        case "Loadmaster", "LM": self = .loadmaster
        case "Purser", "P1", "P2": self = .purser
        case "CabinAttendant", "CA": self = .cabinAttendant
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Duty Code

/// Crew duty code.
public enum DutyCode: Sendable, Equatable {
    case operating
    case deadheading
    case training
    case check
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Operating", "OPR": self = .operating
        case "Deadheading", "DHD": self = .deadheading
        case "Training", "TRN": self = .training
        case "Check", "CHK": self = .check
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Document Status

/// Status of an EFF document.
public enum DocumentStatus: Sendable, Equatable {
    case current
    case superseded
    case draft
    case cancelled
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Current": self = .current
        case "Superseded": self = .superseded
        case "Draft": self = .draft
        case "Cancelled": self = .cancelled
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Signature Type

/// Type of electronic signature.
public enum SignatureType: Sendable, Equatable {
    case dispatch
    case captain
    case firstOfficer
    case loadmaster
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "Dispatch": self = .dispatch
        case "Captain": self = .captain
        case "FirstOfficer": self = .firstOfficer
        case "Loadmaster": self = .loadmaster
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Airport Function

/// Function of an airport in the flight plan context.
public enum AirportFunction: Sendable, Equatable {
    case departureAirport
    case departureAlternateAirport
    case arrivalAirport
    case primaryArrivalAlternateAirport
    case arrivalAlternateAirport
    case arrivalViaAlternateAirport
    case enRouteAlternateAirport
    case contingencySavingAirport
    case contingencySavingEnRouteAlternateAirport
    case primaryContingencySavingAlternate
    case contingencySavingAlternate
    case etopsAdequateAirport
    case etopsSuitableAirport
    case escapeAirport
    case planningEnRouteAlternateAirport
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "DepartureAirport": self = .departureAirport
        case "DepartureAlternateAirport": self = .departureAlternateAirport
        case "ArrivalAirport": self = .arrivalAirport
        case "PrimaryArrivalAlternateAirport": self = .primaryArrivalAlternateAirport
        case "ArrivalAlternateAirport": self = .arrivalAlternateAirport
        case "ArrivalViaAlternateAirport": self = .arrivalViaAlternateAirport
        case "EnRouteAlternateAirport": self = .enRouteAlternateAirport
        case "ContingencySavingAirport": self = .contingencySavingAirport
        case "ContingencySavingEnRouteAlternateAirport": self = .contingencySavingEnRouteAlternateAirport
        case "PrimaryContingencySavingAlternate": self = .primaryContingencySavingAlternate
        case "ContingencySavingAlternate": self = .contingencySavingAlternate
        case "ETOPSAdequateAirport": self = .etopsAdequateAirport
        case "ETOPSSuitableAirport": self = .etopsSuitableAirport
        case "EscapeAirport": self = .escapeAirport
        case "PlanningEnRouteAlternateAirport": self = .planningEnRouteAlternateAirport
        default: self = .unknown(rawValue)
        }
    }
}
