// AirportWeather.swift
// ARINC633Kit
//
// Models for ARINC 633-4 AirportWeather message type.
// Based on AirportWeather.xsd schema.

import Foundation

// MARK: - Top Level

/// Parsed AirportWeather message containing METAR/TAF weather bulletins.
public struct AirportWeather: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public var header: ARINC633Header

    /// Weather bulletins (one per airport/observation).
    public var bulletins: [WeatherBulletin]

    /// Creation time of the weather package.
    public var creationTime: String?

    /// Whether this is a full weather package.
    public var isFullPackage: Bool?

    public init(header: ARINC633Header = ARINC633Header(),
                bulletins: [WeatherBulletin] = [],
                creationTime: String? = nil,
                isFullPackage: Bool? = nil) {
        self.header = header
        self.bulletins = bulletins
        self.creationTime = creationTime
        self.isFullPackage = isFullPackage
    }
}

// MARK: - Weather Bulletin

/// A single weather bulletin for an airport (contains either Observation or Forecast).
public struct WeatherBulletin: Sendable, Equatable {
    /// Sequence number within the package.
    public var sequence: Int?

    /// Airport for this bulletin.
    public var airport: WeatherAirport

    /// METAR observation (mutually exclusive with forecast in a single bulletin).
    public var observation: WeatherObservation?

    /// TAF forecast (mutually exclusive with observation in a single bulletin).
    public var forecast: WeatherForecast?

    public init(sequence: Int? = nil, airport: WeatherAirport = WeatherAirport(),
                observation: WeatherObservation? = nil, forecast: WeatherForecast? = nil) {
        self.sequence = sequence
        self.airport = airport
        self.observation = observation
        self.forecast = forecast
    }
}

// MARK: - Airport

/// Airport information within a weather bulletin.
public struct WeatherAirport: Sendable, Equatable {
    /// ICAO code (e.g., "EDDF").
    public var icaoCode: String?
    /// IATA code (e.g., "FRA").
    public var iataCode: String?
    /// Airport name (e.g., "Frankfurt/Main").
    public var name: String?
    /// Airport function in the flight context.
    public var airportFunction: AirportFunction?

    public init(icaoCode: String? = nil, iataCode: String? = nil,
                name: String? = nil, airportFunction: AirportFunction? = nil) {
        self.icaoCode = icaoCode
        self.iataCode = iataCode
        self.name = name
        self.airportFunction = airportFunction
    }
}

// MARK: - Observation (METAR)

/// A METAR observation with structured weather data.
public struct WeatherObservation: Sendable, Equatable {
    /// Observation time (ISO 8601).
    public var observationTime: String?
    /// Observation type (METAR, SPECI, etc.).
    public var observationType: WeatherReportType

    /// Surface wind data.
    public var wind: ObservedWind?
    /// Visibility data.
    public var visibility: Visibility?
    /// Cloud layers.
    public var cloudLayers: [CloudLayer]
    /// Temperature and dewpoint.
    public var temperature: WeatherTemperature?
    /// Pressure readings.
    public var pressure: WeatherPressure?
    /// Trend information.
    public var trend: WeatherTrend?
    /// Raw METAR text.
    public var rawText: String?

    /// CAVOK flag (Ceiling And Visibility OK).
    public var isCAVOK: Bool
    /// NSC flag (No Significant Clouds).
    public var isNSC: Bool

    public init(observationTime: String? = nil,
                observationType: WeatherReportType = .unknown(""),
                wind: ObservedWind? = nil, visibility: Visibility? = nil,
                cloudLayers: [CloudLayer] = [],
                temperature: WeatherTemperature? = nil, pressure: WeatherPressure? = nil,
                trend: WeatherTrend? = nil, rawText: String? = nil,
                isCAVOK: Bool = false, isNSC: Bool = false) {
        self.observationTime = observationTime
        self.observationType = observationType
        self.wind = wind
        self.visibility = visibility
        self.cloudLayers = cloudLayers
        self.temperature = temperature
        self.pressure = pressure
        self.trend = trend
        self.rawText = rawText
        self.isCAVOK = isCAVOK
        self.isNSC = isNSC
    }
}

// MARK: - Forecast (TAF)

/// A TAF forecast with structured weather data.
public struct WeatherForecast: Sendable, Equatable {
    /// Forecast type (FT, etc.).
    public var forecastType: String?
    /// Forecast validity start time.
    public var forecastStartTime: String?
    /// Forecast issue time.
    public var forecastTime: String?
    /// Forecast validity end time.
    public var forecastEndTime: String?

    /// General forecast conditions.
    public var wind: ObservedWind?
    public var visibility: Visibility?
    public var cloudLayers: [CloudLayer]
    /// Forecast temperatures (max/min).
    public var temperatures: [ForecastTemperature]

    /// Weather changes (TEMPO, BECMG, etc.).
    public var weatherChanges: [WeatherChange]

    /// Raw TAF text.
    public var rawText: String?

    public init(forecastType: String? = nil, forecastStartTime: String? = nil,
                forecastTime: String? = nil, forecastEndTime: String? = nil,
                wind: ObservedWind? = nil, visibility: Visibility? = nil,
                cloudLayers: [CloudLayer] = [], temperatures: [ForecastTemperature] = [],
                weatherChanges: [WeatherChange] = [], rawText: String? = nil) {
        self.forecastType = forecastType
        self.forecastStartTime = forecastStartTime
        self.forecastTime = forecastTime
        self.forecastEndTime = forecastEndTime
        self.wind = wind
        self.visibility = visibility
        self.cloudLayers = cloudLayers
        self.temperatures = temperatures
        self.weatherChanges = weatherChanges
        self.rawText = rawText
    }
}

// MARK: - Weather Report Type

/// Type of weather report.
public enum WeatherReportType: Sendable, Equatable {
    case metar
    case speci
    case taf
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue.uppercased() {
        case "METAR": self = .metar
        case "SPECI": self = .speci
        case "TAF": self = .taf
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Wind

/// Surface wind observation data.
public struct ObservedWind: Sendable, Equatable {
    /// Wind direction in degrees.
    public var direction: Int?
    /// Wind speed.
    public var speed: ARINCSpeed?
    /// Gust speed (if applicable).
    public var gustSpeed: ARINCSpeed?
    /// Whether wind is variable (VRB).
    public var isVariable: Bool

    /// Variable wind range - direction 1.
    public var variableFrom: Int?
    /// Variable wind range - direction 2.
    public var variableTo: Int?

    public init(direction: Int? = nil, speed: ARINCSpeed? = nil,
                gustSpeed: ARINCSpeed? = nil, isVariable: Bool = false,
                variableFrom: Int? = nil, variableTo: Int? = nil) {
        self.direction = direction
        self.speed = speed
        self.gustSpeed = gustSpeed
        self.isVariable = isVariable
        self.variableFrom = variableFrom
        self.variableTo = variableTo
    }
}

// MARK: - Visibility

/// Visibility data.
public struct Visibility: Sendable, Equatable {
    /// Prevailing visibility value.
    public var value: Double?
    /// Visibility unit (m, km, SM).
    public var unit: String?

    public init(value: Double? = nil, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }
}

// MARK: - Cloud Layer

/// A single cloud layer description.
public struct CloudLayer: Sendable, Equatable {
    /// Cloud coverage amount (FEW, SCT, BKN, OVC).
    public var coverage: CloudCover
    /// Cloud base altitude.
    public var base: ARINCAltitude?
    /// Cloud type (CB, TCU, etc.) if specified.
    public var type: String?

    public init(coverage: CloudCover = .unknown(""), base: ARINCAltitude? = nil,
                type: String? = nil) {
        self.coverage = coverage
        self.base = base
        self.type = type
    }
}

// MARK: - Temperature

/// Temperature and dewpoint pair from a METAR observation.
public struct WeatherTemperature: Sendable, Equatable {
    /// Air temperature.
    public var temperature: ARINCTemperature?
    /// Dew point temperature.
    public var dewpoint: ARINCTemperature?

    public init(temperature: ARINCTemperature? = nil, dewpoint: ARINCTemperature? = nil) {
        self.temperature = temperature
        self.dewpoint = dewpoint
    }
}

/// Forecast temperature with time and max/min indicator.
public struct ForecastTemperature: Sendable, Equatable {
    /// Temperature value.
    public var value: ARINCTemperature?
    /// Forecast time for this temperature.
    public var forecastTime: String?
    /// Whether this is maximum or minimum.
    public var maxMin: String?

    public init(value: ARINCTemperature? = nil, forecastTime: String? = nil,
                maxMin: String? = nil) {
        self.value = value
        self.forecastTime = forecastTime
        self.maxMin = maxMin
    }
}

// MARK: - Pressure

/// Atmospheric pressure readings.
public struct WeatherPressure: Sendable, Equatable {
    /// QNH (altimeter setting in hPa).
    public var qnh: ARINCPressure?
    /// Altimeter setting (in inHg).
    public var altimeter: ARINCPressure?

    public init(qnh: ARINCPressure? = nil, altimeter: ARINCPressure? = nil) {
        self.qnh = qnh
        self.altimeter = altimeter
    }
}

// MARK: - Trend

/// METAR trend information (NOSIG, BECMG, TEMPO).
public struct WeatherTrend: Sendable, Equatable {
    /// Trend type (NOSIG, BECMG, TEMPO).
    public var type: String?
    /// Nil significant weather flag.
    public var isNOSIG: Bool

    public init(type: String? = nil, isNOSIG: Bool = false) {
        self.type = type
        self.isNOSIG = isNOSIG
    }
}

// MARK: - Weather Change

/// A weather change group within a TAF (TEMPO, BECMG, etc.).
public struct WeatherChange: Sendable, Equatable {
    /// Change type (TEMPO, BECMG, FM, etc.).
    public var temporary: String?
    /// Start time of the change.
    public var startTime: String?
    /// End time of the change.
    public var endTime: String?
    /// Visibility during change.
    public var visibility: Visibility?
    /// Weather phenomena during change.
    public var weather: String?
    /// Weather intensity.
    public var weatherIntensity: String?

    public init(temporary: String? = nil, startTime: String? = nil,
                endTime: String? = nil, visibility: Visibility? = nil,
                weather: String? = nil, weatherIntensity: String? = nil) {
        self.temporary = temporary
        self.startTime = startTime
        self.endTime = endTime
        self.visibility = visibility
        self.weather = weather
        self.weatherIntensity = weatherIntensity
    }
}
