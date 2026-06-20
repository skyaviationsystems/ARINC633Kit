// ATCFlightPlanParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633 FlightPlanAtcIcao message type.
// Extracts M633Header, M633SupplementaryHeader, AtcMessageText,
// and AtcMessageDetails including ICAO ATC flight plan Items 7-18.

import Foundation

/// SAX parser for ARINC 633 FlightPlanAtcIcao message type.
///
/// Parses the full ATC ICAO flight plan including:
/// - M633Header and M633SupplementaryHeader (same pattern as other parsers)
/// - AtcMessageText raw content (multi-line ATC message)
/// - AtcMessageDetails with Items 7-16 attributes
/// - Item18 variable child elements as key-value dictionary
final class ATCFlightPlanParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = ATCFlightPlan()

    // MARK: - Header Builder State

    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var headerMessageSequence: String?

    // Supplementary header builders
    private var inSuppHeader = false
    private var suppFlightAirlineCode = ""
    private var suppFlightNumber = ""
    private var suppFlightIdentifier: String?
    private var suppDepartureICAO = ""
    private var suppDepartureIATA: String?
    private var suppDepartureName: String?
    private var suppArrivalICAO = ""
    private var suppArrivalIATA: String?
    private var suppArrivalName: String?
    private var suppFlightOriginDate: String?
    private var suppScheduledDeparture: String?
    private var suppAircraftRegistration = ""
    private var suppAircraftType: String?
    private var suppAircraftSubType: String?

    // MARK: - ATC Message Text State

    private var messageTextParagraphs: [String] = []

    // MARK: - AtcMessageDetails State

    private var msgType: String?
    private var msgPriority: String?

    // Item values
    private var callsign: String?
    private var flightRules: String?
    private var typeOfFlight: String?
    private var aircraftType: String?
    private var wakeTurbulence: String?
    private var aircraftEquipment: String?
    private var depAirport: String?
    private var depTime: String?
    private var cruisingSpeed: String?
    private var cruisingLevel: String?
    private var route: String?
    private var arrAirport: String?
    private var estFlightTime: String?
    private var altAirport: String?
    private var item18Dict: [String: String] = [:]

    // MARK: - Section Tracking

    private var inItem18 = false
    private var currentItem18Key: String?

    // MARK: - Public Interface

    /// Parse FlightPlanAtcIcao XML data.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: Fully parsed `ATCFlightPlan`
    /// - Throws: `ARINC633ParseError` on parse failure
    func parse(data: Data) throws -> ATCFlightPlan {
        try run(data: data)
        finalizeResult()
        return result
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "M633Header":
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""
            headerMessageSequence = attributes["messageSequence"]

        case "M633SupplementaryHeader":
            inSuppHeader = true

        case "Flight":
            if inSuppHeader {
                suppFlightOriginDate = attributes["flightOriginDate"]
                suppScheduledDeparture = attributes["scheduledTimeOfDeparture"]
            }

        case "FlightNumber":
            if inSuppHeader {
                suppFlightAirlineCode = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
                suppFlightNumber = attributes["number"] ?? ""
            }

        case "DepartureAirport":
            if inSuppHeader {
                suppDepartureName = attributes["airportName"]
            }

        case "ArrivalAirport":
            if inSuppHeader {
                suppArrivalName = attributes["airportName"]
            }

        case "Aircraft":
            if inSuppHeader {
                suppAircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "AircraftModel":
            if inSuppHeader {
                suppAircraftSubType = attributes["airlineSpecificSubType"]
            }

        case "AtcMessageDetails":
            msgType = attributes["messageType"]
            msgPriority = attributes["messagePriority"]

        case "Item7":
            callsign = attributes["aTCCallsign"]

        case "Item8":
            flightRules = attributes["flightRules"]
            typeOfFlight = attributes["typeOfFlight"]

        case "Item9":
            aircraftType = attributes["typeOfAircraft"]
            wakeTurbulence = attributes["wakeTurbulence"]

        case "Item10":
            aircraftEquipment = attributes["aircraftEquipment"]

        case "Item13":
            depAirport = attributes["departureAirport"]
            depTime = attributes["departureTime"]

        case "Item15":
            cruisingSpeed = attributes["cruisingSpeed"]
            cruisingLevel = attributes["cruisingLevel"]
            route = attributes["route"]

        case "Item16":
            arrAirport = attributes["arrivalAirport"]
            estFlightTime = attributes["estimatedFlightTime"]
            altAirport = attributes["alternateAirport"]

        case "Item18":
            inItem18 = true

        default:
            // Inside Item18, every child element is a key for the dictionary
            if inItem18 {
                currentItem18Key = elementName
            }
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633SupplementaryHeader":
            inSuppHeader = false

        case "FlightIdentifier":
            if inSuppHeader {
                suppFlightIdentifier = text.isEmpty ? nil : text
            }

        case "AirportICAOCode":
            if inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureICAO = text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalICAO = text
                }
            }

        case "AirportIATACode":
            if inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureIATA = text.isEmpty ? nil : text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalIATA = text.isEmpty ? nil : text
                }
            }

        case "AircraftICAOType":
            if inSuppHeader {
                suppAircraftType = text.isEmpty ? nil : text
            }

        case "Text":
            // Accumulate ATC message text paragraphs
            if stackContains("AtcMessageText") && stackContains("Paragraph") {
                // Use the raw character buffer to preserve multi-line content
                let rawText = characterBuffer
                if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messageTextParagraphs.append(rawText)
                }
            }

        case "Item18":
            inItem18 = false
            currentItem18Key = nil

        default:
            // Inside Item18, capture child element text as key-value pair
            if inItem18, let key = currentItem18Key, key == elementName, !text.isEmpty {
                item18Dict[key] = text
                currentItem18Key = nil
            }
        }
    }

    // MARK: - Finalize

    private func finalizeResult() {
        let header = ARINC633Header(
            versionNumber: headerVersionNumber,
            timestamp: headerTimestamp,
            messageSequence: headerMessageSequence
        )

        let supplementaryHeader = SupplementaryHeader(
            flight: ARINCHeaderFlight(
                airlineCode: suppFlightAirlineCode,
                flightNumber: suppFlightNumber,
                flightIdentifier: suppFlightIdentifier,
                departure: ARINCHeaderAirport(
                    icaoCode: suppDepartureICAO,
                    iataCode: suppDepartureIATA,
                    name: suppDepartureName
                ),
                arrival: ARINCHeaderAirport(
                    icaoCode: suppArrivalICAO,
                    iataCode: suppArrivalIATA,
                    name: suppArrivalName
                ),
                scheduledDepartureTime: suppScheduledDeparture,
                flightOriginDate: suppFlightOriginDate
            ),
            aircraft: ARINCHeaderAircraft(
                registration: suppAircraftRegistration,
                aircraftType: suppAircraftType,
                engineType: suppAircraftSubType
            )
        )

        // Join message text paragraphs (typically just one for ATC plans)
        let rawContent: String? = messageTextParagraphs.isEmpty
            ? nil
            : messageTextParagraphs.joined(separator: "\n")

        result = ATCFlightPlan(
            header: header,
            supplementaryHeader: supplementaryHeader,
            rawContent: rawContent,
            messageType: msgType,
            messagePriority: msgPriority,
            callsign: callsign,
            flightRules: flightRules,
            typeOfFlight: typeOfFlight,
            aircraftType: aircraftType,
            wakeTurbulence: wakeTurbulence,
            aircraftEquipment: aircraftEquipment,
            departureAirport: depAirport,
            departureTime: depTime,
            cruisingSpeed: cruisingSpeed,
            cruisingLevel: cruisingLevel,
            route: route,
            arrivalAirport: arrAirport,
            estimatedFlightTime: estFlightTime,
            alternateAirport: altAirport,
            item18: item18Dict
        )
    }
}
