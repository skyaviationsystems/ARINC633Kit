// AirportWeatherParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633-4 AirportWeather message type.
// Handles METAR observations and TAF forecasts with structured weather data.

import Foundation

// MARK: - Weather Section State Machine

/// Section context for AirportWeather parsing.
private enum WeatherSection {
    case none
    case bulletin
    case airport
    case observation
    case observationDetails
    case surfaceWind
    case windDirection
    case windVariableRange
    case windSpeed
    case windGust
    case visibilitiesAndWeather
    case visibility
    case clouds
    case temperatures
    case pressures
    case trend
    case forecast
    case forecastGeneral
    case forecastTemperatures
    case weatherChanges
    case weatherChange
    case observationText
    case forecastText
}

/// SAX parser for ARINC 633-4 AirportWeather message type.
final class AirportWeatherParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = AirportWeather()

    // MARK: - Section State Machine

    private var currentSection: WeatherSection = .none

    // MARK: - Builder State

    private var currentBulletin = WeatherBulletin()
    private var currentObservation = WeatherObservation()
    private var currentForecast = WeatherForecast()
    private var currentWind = ObservedWind()
    private var currentTemperature = WeatherTemperature()
    private var currentPressure = WeatherPressure()
    private var currentTrend = WeatherTrend()
    private var currentCloudLayer = CloudLayer()
    private var currentWeatherChange = WeatherChange()
    private var currentVisibility = Visibility()
    private var currentForecastTemp = ForecastTemperature()

    // Track which direction element we are inside
    private var inDirection1 = false
    private var inDirection2 = false
    private var inVariableRange = false

    // Track if we are in a Forecast block (TAF)
    private var inForecast = false
    // Track if we are in a weather change's visibility/weather
    private var inWeatherChangeVAW = false
    // Track if we are in a trend's visibility/weather
    private var inTrendVAW = false

    // MARK: - Public Interface

    /// Parse AirportWeather XML data.
    func parse(data: Data) throws -> AirportWeather {
        try run(data: data)
        return result
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "AirportWeather":
            result.creationTime = attributes["creationTime"]
            if let fp = attributes["fullPackage"] {
                result.isFullPackage = (fp == "true")
            }

        case "M633Header":
            result.header = ARINC633Header(
                versionNumber: attributes["versionNumber"] ?? "",
                timestamp: attributes["timestamp"] ?? ""
            )

        case "WeatherBulletin":
            currentBulletin = WeatherBulletin()
            currentBulletin.sequence = Int(attributes["sequence"] ?? "")
            currentSection = .bulletin

        case "Airport":
            if currentSection == .bulletin {
                currentSection = .airport
                currentBulletin.airport.name = attributes["airportName"]
                if let fn = attributes["airportFunction"] {
                    currentBulletin.airport.airportFunction = AirportFunction(rawValue: fn)
                }
            }

        case "Observation":
            currentSection = .observation
            currentObservation = WeatherObservation()
            currentObservation.observationTime = attributes["observationTime"]
            if let ot = attributes["observationType"] {
                currentObservation.observationType = WeatherReportType(rawValue: ot)
            }
            inForecast = false

        case "ObservationDetails":
            currentSection = .observationDetails

        case "Forecast":
            currentSection = .forecast
            inForecast = true
            currentForecast = WeatherForecast()
            currentForecast.forecastType = attributes["forecastType"]
            currentForecast.forecastStartTime = attributes["forecastStartTime"]
            currentForecast.forecastTime = attributes["forecastTime"]
            currentForecast.forecastEndTime = attributes["forecastEndTime"]

        case "ForecastDetails":
            currentSection = .forecast

        case "ForecastGeneral":
            currentSection = .forecastGeneral

        case "SurfaceWind", "SurfaceWinds":
            if elementName == "SurfaceWind" {
                currentSection = .surfaceWind
                currentWind = ObservedWind()
            }

        case "Direction":
            if currentSection == .surfaceWind || currentSection == .windDirection || currentSection == .forecastGeneral {
                currentSection = .windDirection
                inDirection1 = false
                inDirection2 = false
            }

        case "Direction1":
            inDirection1 = true
            inDirection2 = false

        case "Direction2":
            inDirection2 = true
            inDirection1 = false

        case "VariableWindRange":
            inVariableRange = true

        case "Speed":
            currentSection = .windSpeed

        case "GustSpeed":
            currentSection = .windGust

        case "VisibilitiesAndWeather":
            if stackContains("WeatherChange") {
                inWeatherChangeVAW = true
                inTrendVAW = false
            } else if stackContains("Trend") {
                inTrendVAW = true
                inWeatherChangeVAW = false
            } else {
                currentSection = .visibilitiesAndWeather
                inWeatherChangeVAW = false
                inTrendVAW = false
            }

        case "Clouds":
            currentSection = .clouds

        case "CloudDescription":
            currentCloudLayer = CloudLayer()
            if let cover = attributes["cloudCover"] {
                currentCloudLayer.coverage = CloudCover(rawValue: cover)
            }

        case "Temperatures":
            if inForecast && currentSection == .forecastGeneral {
                currentSection = .forecastTemperatures
            } else {
                currentSection = .temperatures
                currentTemperature = WeatherTemperature()
            }

        case "Temperature":
            if currentSection == .forecastTemperatures {
                currentForecastTemp = ForecastTemperature()
                currentForecastTemp.forecastTime = attributes["forecastTime"]
                currentForecastTemp.maxMin = attributes["maximumMinimumTemperature"]
            }

        case "Pressures":
            currentSection = .pressures
            currentPressure = WeatherPressure()

        case "Trend":
            currentSection = .trend
            currentTrend = WeatherTrend()

        case "WeatherChanges":
            currentSection = .weatherChanges

        case "WeatherChange":
            currentSection = .weatherChange
            currentWeatherChange = WeatherChange()
            currentWeatherChange.temporary = attributes["temporary"]
            currentWeatherChange.startTime = attributes["startTime"]
            currentWeatherChange.endTime = attributes["endTime"]

        case "ObservationText":
            currentSection = .observationText

        case "ForecastText":
            currentSection = .forecastText

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        // Airport codes
        case "AirportICAOCode":
            if currentSection == .airport || stackContains("Airport") {
                currentBulletin.airport.icaoCode = text
            }

        case "AirportIATACode":
            if currentSection == .airport || stackContains("Airport") {
                currentBulletin.airport.iataCode = text
            }

        case "Airport":
            currentSection = .bulletin

        // Value element -- context-dependent
        case "Value":
            handleValue(text)

        // CAVOK
        case "CeilingAndVisibilityOK":
            if text.contains("CAVOK") {
                if inForecast {
                    // In forecast context, no specific CAVOK handling needed
                } else {
                    currentObservation.isCAVOK = true
                }
            }

        // NSC
        case "NilSignificantClouds":
            if text == "NSC" {
                currentObservation.isNSC = true
            }

        // NOSIG trend
        case "NilSignificantWeather":
            if text == "NOSIG" {
                if inTrendVAW || currentSection == .trend {
                    currentTrend.isNOSIG = true
                    currentTrend.type = "NOSIG"
                }
            }

        // Weather phenomena in changes
        case "Weather":
            if inWeatherChangeVAW || currentSection == .weatherChange {
                currentWeatherChange.weather = text
                currentWeatherChange.weatherIntensity = currentAttributes["intensity"]
            }

        // Cloud layer
        case "Ceiling":
            // Handled by Value
            break

        case "CloudDescription":
            if inForecast {
                currentForecast.cloudLayers.append(currentCloudLayer)
            } else {
                currentObservation.cloudLayers.append(currentCloudLayer)
            }

        // Direction end
        case "Direction":
            if !inVariableRange {
                currentSection = .surfaceWind
            }

        case "Direction1":
            inDirection1 = false

        case "Direction2":
            inDirection2 = false

        case "VariableWindRange":
            inVariableRange = false

        // Wind end
        case "SurfaceWind":
            if inForecast {
                currentForecast.wind = currentWind
            } else {
                currentObservation.wind = currentWind
            }
            currentSection = inForecast ? .forecastGeneral : .observationDetails

        // Visibility end
        case "VisibilitiesAndWeather":
            if inWeatherChangeVAW {
                inWeatherChangeVAW = false
            } else if inTrendVAW {
                inTrendVAW = false
            } else {
                currentSection = inForecast ? .forecastGeneral : .observationDetails
            }

        // Temperature end
        case "Temperatures":
            if currentSection == .forecastTemperatures {
                currentSection = .forecastGeneral
            } else {
                if !inForecast {
                    currentObservation.temperature = currentTemperature
                }
                currentSection = .observationDetails
            }

        case "Temperature":
            if currentSection == .forecastTemperatures {
                currentForecast.temperatures.append(currentForecastTemp)
            }

        // Pressure end
        case "Pressures":
            if !inForecast {
                currentObservation.pressure = currentPressure
            }
            currentSection = inForecast ? .forecastGeneral : .observationDetails

        // Trend end
        case "Trend":
            currentObservation.trend = currentTrend
            currentSection = .observationDetails

        // Weather change end
        case "WeatherChange":
            currentForecast.weatherChanges.append(currentWeatherChange)
            currentSection = .weatherChanges

        case "WeatherChanges":
            currentSection = .forecast

        case "ForecastGeneral":
            currentSection = .forecast

        // Raw text
        case "Text":
            if currentSection == .observationText {
                currentObservation.rawText = text
            } else if currentSection == .forecastText {
                currentForecast.rawText = text
            }

        // Observation/Forecast end
        case "Observation":
            currentBulletin.observation = currentObservation
            currentSection = .bulletin

        case "ObservationDetails":
            currentSection = .observation

        case "ObservationText":
            currentSection = .observation

        case "Forecast":
            currentBulletin.forecast = currentForecast
            currentSection = .bulletin
            inForecast = false

        case "ForecastDetails":
            currentSection = .forecast

        case "ForecastText":
            currentSection = .forecast

        // Bulletin end
        case "WeatherBulletin":
            result.bulletins.append(currentBulletin)
            currentBulletin = WeatherBulletin()
            currentSection = .none

        default:
            break
        }
    }

    // MARK: - Value Handling

    private func handleValue(_ text: String) {
        let unit = currentAttributes["unit"] ?? ""

        // Wind direction values
        if stackContains("Directions") || stackContains("Direction") || stackContains("Direction1") || stackContains("Direction2") {
            if let dirValue = Int(text) {
                if inDirection1 {
                    currentWind.variableFrom = dirValue
                } else if inDirection2 {
                    currentWind.variableTo = dirValue
                } else if !inVariableRange {
                    currentWind.direction = dirValue
                }
            }
            return
        }

        // Wind speed values
        if stackContains("Speed") && (stackContains("SurfaceWind") || stackContains("Speeds")) {
            if let val = Double(text) {
                currentWind.speed = ARINCSpeed(value: val, unit: unit)
            }
            return
        }

        // Gust speed
        if stackContains("GustSpeed") {
            if let val = Double(text) {
                currentWind.gustSpeed = ARINCSpeed(value: val, unit: unit)
            }
            return
        }

        // Visibility values
        if stackContains("PrevailingVisibility") {
            if let val = Double(text) {
                let vis = Visibility(value: val, unit: unit)
                if inWeatherChangeVAW {
                    currentWeatherChange.visibility = vis
                } else if inForecast {
                    currentForecast.visibility = vis
                } else {
                    currentObservation.visibility = vis
                }
            }
            return
        }

        // Cloud ceiling values
        if stackContains("Ceiling") || stackContains("CloudDescription") {
            if let val = Double(text) {
                currentCloudLayer.base = ARINCAltitude(value: val, unit: unit)
            }
            return
        }

        // Temperature values
        if stackContains("AirTemperature") {
            if let val = Double(text) {
                currentTemperature.temperature = ARINCTemperature(value: val, unit: unit)
            }
            return
        }

        if stackContains("DewPointTemperature") {
            if let val = Double(text) {
                currentTemperature.dewpoint = ARINCTemperature(value: val, unit: unit)
            }
            return
        }

        // Forecast temperature
        if stackContains("Temperature") && currentSection == .forecastTemperatures {
            if let val = Double(text) {
                currentForecastTemp.value = ARINCTemperature(value: val, unit: unit)
            }
            return
        }

        // Pressure values
        if stackContains("QNH") {
            if let val = Double(text) {
                currentPressure.qnh = ARINCPressure(value: val, unit: unit)
            }
            return
        }

        if stackContains("Altimeter") {
            if let val = Double(text) {
                currentPressure.altimeter = ARINCPressure(value: val, unit: unit)
            }
            return
        }
    }
}
