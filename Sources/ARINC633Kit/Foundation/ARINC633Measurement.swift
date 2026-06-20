// ARINC633Measurement.swift
// ARINC633Kit
//
// Measurement protocol and typed measurement structs for all m633common physical quantities.
// Unit values sourced from m633common.xsd unit type enumerations.

import Foundation

// MARK: - Protocol

/// Protocol for all ARINC 633 measurement values with optional correction support.
public protocol ARINC633Measurement: Sendable, Equatable {
    var value: Double { get }
    var unit: String { get }
    var correctedValue: Double? { get }
    var correctionSource: String? { get }
}

// MARK: - Weight

/// Weight measurement (units: kg, t, lb, hlb)
public struct ARINCWeight: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "kg",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to kilograms.
    public var kilograms: Double {
        switch unit.lowercased() {
        case "lb", "lbs":
            return value * 0.453592
        case "hlb":
            return value * 100.0 * 0.453592
        case "t":
            return value * 1000.0
        default:
            return value
        }
    }
}

// MARK: - Speed

/// Speed measurement (units: kt, m/s, km/h, ft/min)
public struct ARINCSpeed: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "kt",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to knots.
    public var knots: Double {
        switch unit.lowercased() {
        case "m/s":
            return value * 1.94384
        case "km/h":
            return value * 0.539957
        case "ft/min":
            return value * 0.00987473
        default:
            return value
        }
    }
}

// MARK: - Altitude

/// Altitude measurement (units: ft/100, ft/1000, ft, m/100, m/10, m)
public struct ARINCAltitude: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "ft/100",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to feet.
    public var feet: Double {
        switch unit.lowercased() {
        case "ft/100":
            return value * 100.0
        case "ft/1000":
            return value * 1000.0
        case "m":
            return value * 3.28084
        case "m/100":
            return value * 100.0 * 3.28084
        case "m/10":
            return value * 10.0 * 3.28084
        case "ft":
            return value
        default:
            return value
        }
    }
}

// MARK: - Distance

/// Distance measurement (units: NM, km, m, ft, SM)
public struct ARINCDistance: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "NM",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to nautical miles.
    public var nauticalMiles: Double {
        switch unit.lowercased() {
        case "km":
            return value * 0.539957
        case "m":
            return value * 0.000539957
        case "ft":
            return value * 0.000164579
        case "sm":
            return value * 0.868976
        default:
            return value
        }
    }
}

// MARK: - Temperature

/// Temperature measurement (units: C, F, K)
public struct ARINCTemperature: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "C",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to Celsius.
    public var celsius: Double {
        switch unit.uppercased() {
        case "F":
            return (value - 32.0) * 5.0 / 9.0
        case "K":
            return value - 273.15
        default:
            return value
        }
    }
}

// MARK: - Pressure

/// Pressure measurement (units: hPa, mbar, in/100Hg)
public struct ARINCPressure: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "hPa",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to hectopascals.
    public var hectopascals: Double {
        switch unit.lowercased() {
        case "in/100hg":
            return value * 100.0 * 33.8639
        default:
            // hPa and mbar are equivalent
            return value
        }
    }
}

// MARK: - Volume

/// Volume measurement (units: l, ug, ig, m3, cm3)
public struct ARINCVolume: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "l",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to liters.
    public var liters: Double {
        switch unit.lowercased() {
        case "ug":
            return value * 3.78541
        case "ig":
            return value * 4.54609
        case "m3":
            return value * 1000.0
        case "cm3":
            return value * 0.001
        default:
            return value
        }
    }
}

// MARK: - Flow

/// Flow rate measurement (units: kg/h, kg/s, lb/h, lb/s, kg/mn, hlb/h)
public struct ARINCFlow: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "kg/h",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }
}

// MARK: - Density

/// Density measurement (units: g/cm3, lb/l, lb/ug, lb/m3, lb/ig, kg/l, kg/m3, kg/ig, kg/ug)
public struct ARINCDensity: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "kg/l",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }
}

// MARK: - Mach Number

/// Mach number measurement (dimensionless).
public struct ARINCMachNumber: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }
}

// MARK: - Time

/// Time measurement (ISO 8601 dateTime string).
public struct ARINCTime: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    /// The raw datetime string from the XML.
    public let dateTimeString: String?

    public init(value: Double = 0, unit: String = "",
                correctedValue: Double? = nil, correctionSource: String? = nil,
                dateTimeString: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
        self.dateTimeString = dateTimeString
    }
}

// MARK: - Direction

/// Direction/heading measurement (units: deg, rad).
public struct ARINCDirection: ARINC633Measurement {
    public let value: Double
    public let unit: String
    public let correctedValue: Double?
    public let correctionSource: String?

    public init(value: Double, unit: String = "deg",
                correctedValue: Double? = nil, correctionSource: String? = nil) {
        self.value = value
        self.unit = unit
        self.correctedValue = correctedValue
        self.correctionSource = correctionSource
    }

    /// Value converted to degrees.
    public var degrees: Double {
        switch unit.lowercased() {
        case "rad":
            return value * 180.0 / .pi
        default:
            return value
        }
    }
}
