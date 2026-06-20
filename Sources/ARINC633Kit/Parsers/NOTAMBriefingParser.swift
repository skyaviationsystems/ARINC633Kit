// NOTAMBriefingParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633 NOTAMBriefing message type.
// Extracts all NOTAM items with severity, Q-codes, altitudes, and briefing sections.

import Foundation

/// SAX parser for ARINC 633 NOTAMBriefing message type.
///
/// Handles large briefing files (1MB+, hundreds of NOTAMs) efficiently via streaming SAX.
/// Parses M633Header, M633SupplementaryHeader, and each `<NOTAM>` element with all child data.
final class NOTAMBriefingParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = NOTAMBriefing()

    // MARK: - Header Builder State

    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var headerMessageSequence: String?

    // Supplementary header builders
    private var inSuppHeader = false
    private var suppFlightAirlineCode = ""
    private var suppFlightNumber = ""
    private var suppFlightIdentifier: String?
    private var suppCommercialFlightNumber: String?
    private var suppDepartureICAO = ""
    private var suppDepartureIATA: String?
    private var suppArrivalICAO = ""
    private var suppArrivalIATA: String?
    private var suppFlightOriginDate: String?
    private var suppScheduledDeparture: String?
    private var suppAircraftRegistration = ""
    private var suppAircraftType: String?
    private var suppAircraftSubType: String?

    // MARK: - NOTAM Builder State

    private var inNOTAM = false
    private var currentNOTAM = NOTAMItem()
    private var notamTextParagraphs: [String] = []

    // MARK: - Section Tracking

    private var inUpperAltitude = false
    private var inLowerAltitude = false

    // MARK: - Public Interface

    /// Parse NOTAMBriefing XML data.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: Fully parsed `NOTAMBriefing`
    /// - Throws: `ARINC633ParseError` on parse failure
    func parse(data: Data) throws -> NOTAMBriefing {
        try run(data: data)
        finalizeHeaders()
        return result
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "NOTAMBriefing":
            result.briefingType = attributes["briefingType"]
            result.creationTime = attributes["creationTime"]
            result.fullPackage = attributes["fullPackage"] == "true"

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
            if inSuppHeader && !inNOTAM {
                suppFlightAirlineCode = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
                suppFlightNumber = attributes["number"] ?? ""
            }

        case "Aircraft":
            if inSuppHeader && !inNOTAM {
                suppAircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "AircraftModel":
            if inSuppHeader && !inNOTAM {
                suppAircraftSubType = attributes["airlineSpecificSubType"]
            }

        case "NOTAM":
            inNOTAM = true
            currentNOTAM = NOTAMItem()
            notamTextParagraphs = []

            // Capture all NOTAM element attributes
            currentNOTAM.issuer = attributes["issuer"]
            currentNOTAM.source = attributes["source"]
            currentNOTAM.serial = attributes["serial"]
            currentNOTAM.series = attributes["series"]
            currentNOTAM.year = attributes["year"]
            currentNOTAM.startValidTime = attributes["startValidTime"]
            currentNOTAM.endValidTime = attributes["endValidTime"]
            currentNOTAM.creationTime = attributes["creationTime"]

        case "ICAONOTAMInformation":
            if inNOTAM {
                currentNOTAM.qcode1 = attributes["qcode1"]
                currentNOTAM.qcode2 = attributes["qcode2"]
                currentNOTAM.trafficIndicator = attributes["trafficIndicator"]
                currentNOTAM.scope = attributes["scope"]
            }

        case "Upper":
            if inNOTAM && stackContains("Altitudes") {
                inUpperAltitude = true
                inLowerAltitude = false
            }

        case "Lower":
            if inNOTAM && stackContains("Altitudes") {
                inLowerAltitude = true
                inUpperAltitude = false
            }

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633Header":
            // Header finalized in finalizeHeaders()
            break

        case "M633SupplementaryHeader":
            inSuppHeader = false

        // -- Supplementary header child elements --

        case "FlightIdentifier":
            if inSuppHeader && !inNOTAM {
                suppFlightIdentifier = text.isEmpty ? nil : text
            }

        case "CommercialFlightNumber":
            if inSuppHeader && !inNOTAM {
                suppCommercialFlightNumber = text.isEmpty ? nil : text
            }

        case "AirportICAOCode":
            if inNOTAM {
                // Inside a NOTAM's Keys/Airports/Airport
                if stackContains("Keys") {
                    currentNOTAM.airport = text
                }
            } else if inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureICAO = text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalICAO = text
                }
            }

        case "AirportIATACode":
            if !inNOTAM && inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureIATA = text.isEmpty ? nil : text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalIATA = text.isEmpty ? nil : text
                }
            }

        case "AircraftICAOType":
            if inSuppHeader && !inNOTAM {
                suppAircraftType = text.isEmpty ? nil : text
            }

        // -- NOTAM child elements --

        case "NOTAMSubject":
            if inNOTAM && !text.isEmpty {
                // Parse severity from "sev:medium" pattern
                if text.hasPrefix("sev:") {
                    let severity = String(text.dropFirst(4))
                    if !severity.isEmpty {
                        currentNOTAM.severity = severity
                    }
                }
            }

        case "BriefingSection":
            if inNOTAM && !text.isEmpty {
                currentNOTAM.briefingSections.append(text)
            }

        case "Text":
            if inNOTAM && stackContains("NOTAMText") && stackContains("Paragraph") {
                if !text.isEmpty {
                    notamTextParagraphs.append(text)
                }
            }

        case "Value":
            if inNOTAM && stackContains("Altitudes") {
                if let intVal = Int(text) {
                    if inUpperAltitude {
                        currentNOTAM.upperAltitude = intVal
                    } else if inLowerAltitude {
                        currentNOTAM.lowerAltitude = intVal
                    }
                }
            }

        case "Upper":
            inUpperAltitude = false

        case "Lower":
            inLowerAltitude = false

        case "NOTAM":
            // Finalize current NOTAM
            if !notamTextParagraphs.isEmpty {
                currentNOTAM.text = notamTextParagraphs.joined(separator: "\n")
            }
            result.notams.append(currentNOTAM)
            currentNOTAM = NOTAMItem()
            notamTextParagraphs = []
            inNOTAM = false
            inUpperAltitude = false
            inLowerAltitude = false

        default:
            break
        }
    }

    // MARK: - Finalize

    private func finalizeHeaders() {
        result.header = ARINC633Header(
            versionNumber: headerVersionNumber,
            timestamp: headerTimestamp,
            messageSequence: headerMessageSequence
        )
        result.supplementaryHeader = SupplementaryHeader(
            flight: ARINCHeaderFlight(
                airlineCode: suppFlightAirlineCode,
                flightNumber: suppFlightNumber,
                flightIdentifier: suppFlightIdentifier,
                commercialFlightNumber: suppCommercialFlightNumber,
                departure: ARINCHeaderAirport(
                    icaoCode: suppDepartureICAO,
                    iataCode: suppDepartureIATA
                ),
                arrival: ARINCHeaderAirport(
                    icaoCode: suppArrivalICAO,
                    iataCode: suppArrivalIATA
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
    }
}
