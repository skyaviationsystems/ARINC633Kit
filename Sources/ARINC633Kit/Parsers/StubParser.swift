// StubParser.swift
// ARINC633Kit
//
// Generic SAX parser for remaining ARINC 633-4 message types.
// Extracts standard M633Header and M633SupplementaryHeader, captures root element
// attributes, and stores raw XML text content for future full parsing.

import Foundation

/// Generic parser that extracts common header fields from any ARINC 633-4 message.
///
/// Used for message types that do not yet have full domain parsers:
/// NOTAM, ATIS, ATCFlightPlan, RAIM, PIREP, Hazards, OrganizedTracks,
/// AirspaceData, WBA, FUEL, DeIcing, PaxList, RegionWeather, UpperAirData, AirportData.
///
/// Extracts:
/// - M633Header (versionNumber, timestamp)
/// - M633SupplementaryHeader (flight, aircraft context)
/// - Root element attributes (message-type-specific attributes)
/// - Raw text content accumulated from all elements
final class StubParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private(set) var header = ARINC633Header()
    private(set) var supplementaryHeader = SupplementaryHeader()
    private(set) var rootAttributes: [String: String] = [:]

    // MARK: - Header Builder State

    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var headerMessageSequence: String?
    private var flightOriginDate: String?
    private var scheduledDepartureTime: String?
    private var airlineCode = ""
    private var flightNumberStr = ""
    private var flightIdentifier: String?
    private var commercialFlightNumber: String?
    private var departureICAO = ""
    private var departureIATA: String?
    private var arrivalICAO = ""
    private var arrivalIATA: String?
    private var aircraftRegistration = ""
    private var aircraftType: String?
    private var aircraftSubType: String?
    private var departureName: String?
    private var arrivalName: String?
    private var flightKeyIdentifier: String?

    // MARK: - Section Tracking

    private var inSupplementaryHeader = false
    private var isRootElement = true
    private var rootElementName = ""

    // MARK: - Public Parse Methods

    /// Parse any ARINC 633-4 message and extract header information.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: Tuple of (header, supplementaryHeader, rootAttributes, rootElementName)
    /// - Throws: `ARINC633ParseError` on parse failure
    func parse(data: Data) throws -> (ARINC633Header, SupplementaryHeader, [String: String], String) {
        try run(data: data)
        return (header, supplementaryHeader, rootAttributes, rootElementName)
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        if isRootElement {
            rootElementName = elementName
            rootAttributes = attributes
            isRootElement = false
            return
        }

        switch elementName {
        case "M633Header", "M633LTDHeader":
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""
            headerMessageSequence = attributes["messageSequence"]

        case "M633SupplementaryHeader", "M633LTDSupplementaryHeader":
            inSupplementaryHeader = true

        case "Flight":
            if inSupplementaryHeader {
                flightOriginDate = attributes["flightOriginDate"]
                scheduledDepartureTime = attributes["scheduledTimeOfDeparture"]
            }

        case "FlightNumber":
            if inSupplementaryHeader {
                airlineCode = attributes["airlineIATACode"] ?? ""
                flightNumberStr = attributes["number"] ?? ""
            }

        case "DepartureAirport":
            if inSupplementaryHeader { departureName = attributes["airportName"] }

        case "ArrivalAirport":
            if inSupplementaryHeader { arrivalName = attributes["airportName"] }

        case "Aircraft":
            if inSupplementaryHeader {
                aircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "AircraftModel":
            if inSupplementaryHeader { aircraftSubType = attributes["airlineSpecificSubType"] }

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633Header", "M633LTDHeader":
            header = ARINC633Header(
                versionNumber: headerVersionNumber,
                timestamp: headerTimestamp,
                messageSequence: headerMessageSequence
            )

        case "M633SupplementaryHeader", "M633LTDSupplementaryHeader":
            inSupplementaryHeader = false
            let flight = ARINCHeaderFlight(
                airlineCode: airlineCode,
                flightNumber: flightNumberStr,
                flightIdentifier: flightIdentifier,
                commercialFlightNumber: commercialFlightNumber,
                departure: ARINCHeaderAirport(icaoCode: departureICAO, iataCode: departureIATA, name: departureName),
                arrival: ARINCHeaderAirport(icaoCode: arrivalICAO, iataCode: arrivalIATA, name: arrivalName),
                scheduledDepartureTime: scheduledDepartureTime,
                flightOriginDate: flightOriginDate
            )
            let aircraft = ARINCHeaderAircraft(
                registration: aircraftRegistration,
                aircraftType: aircraftType,
                engineType: aircraftSubType
            )
            supplementaryHeader = SupplementaryHeader(
                flight: flight,
                aircraft: aircraft,
                flightKeyIdentifier: flightKeyIdentifier
            )

        case "FlightKeyIdentifier":
            if inSupplementaryHeader { flightKeyIdentifier = text.isEmpty ? nil : text }

        case "FlightIdentifier":
            if inSupplementaryHeader { flightIdentifier = text.isEmpty ? nil : text }

        case "CommercialFlightNumber":
            if inSupplementaryHeader { commercialFlightNumber = text.isEmpty ? nil : text }

        case "AirportICAOCode":
            if inSupplementaryHeader {
                if stackContains("DepartureAirport") {
                    departureICAO = text
                } else if stackContains("ArrivalAirport") {
                    arrivalICAO = text
                }
            }

        case "AirportIATACode":
            if inSupplementaryHeader {
                if stackContains("DepartureAirport") {
                    departureIATA = text.isEmpty ? nil : text
                } else if stackContains("ArrivalAirport") {
                    arrivalIATA = text.isEmpty ? nil : text
                }
            }

        case "AircraftICAOType":
            if inSupplementaryHeader { aircraftType = text.isEmpty ? nil : text }

        default:
            break
        }
    }
}
