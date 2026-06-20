// CrewListParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633-4 CrewList message type.
// Extracts crew members with personal info, ranks, duty codes, qualifications.

import Foundation

/// SAX parser for ARINC 633-4 CrewList message type.
final class CrewListParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = CrewList()

    // MARK: - Builder State

    private var currentMember = CrewMember()
    private var inCrewInfo = false
    private var inPersonalInfo = false
    private var inLanguages = false
    private var inQualifications = false
    private var inConnectionInfo = false

    // Header builders
    private var headerVersionNumber = ""
    private var headerTimestamp = ""
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
    private var inDepartureAirport = false
    private var inArrivalAirport = false
    private var inSuppHeader = false

    // MARK: - Public Interface

    /// Parse CrewList XML data.
    func parse(data: Data) throws -> CrewList {
        try run(data: data)
        finalizeHeaders()
        return result
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "M633Header":
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""

        case "M633SupplementaryHeader":
            inSuppHeader = true

        case "Flight":
            if inSuppHeader {
                suppFlightOriginDate = attributes["flightOriginDate"]
                suppScheduledDeparture = attributes["scheduledTimeOfDeparture"]
            }

        case "FlightNumber":
            if inSuppHeader && !inConnectionInfo {
                suppFlightAirlineCode = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
                suppFlightNumber = attributes["number"] ?? ""
            }

        case "DepartureAirport":
            if inSuppHeader && !inConnectionInfo {
                inDepartureAirport = true
                inArrivalAirport = false
            }

        case "ArrivalAirport":
            if inSuppHeader && !inConnectionInfo {
                inArrivalAirport = true
                inDepartureAirport = false
            }

        case "Aircraft":
            if inSuppHeader {
                suppAircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "AircraftModel":
            if inSuppHeader {
                suppAircraftSubType = attributes["airlineSpecificSubType"]
            }

        case "CrewInfo":
            inCrewInfo = true
            currentMember = CrewMember()
            if let cockpit = attributes["cockpitCrew"] {
                currentMember.isCockpitCrew = (cockpit == "true")
            }

        case "PersonalInfo":
            if inCrewInfo {
                inPersonalInfo = true
                // Inner PersonalInfo element carries name attributes
                if let surname = attributes["surname"] {
                    currentMember.surname = surname
                }
                if let givenName = attributes["givenName"] {
                    currentMember.givenName = givenName
                }
                if let title = attributes["title"] {
                    currentMember.title = title
                }
            }

        case "TravelDocument":
            if inCrewInfo {
                currentMember.travelDocument = CrewTravelDocument(
                    documentType: attributes["travelDocumentType"],
                    documentId: attributes["travelDocumentId"],
                    nationality: attributes["nationality"],
                    dateOfBirth: attributes["dateOfBirth"],
                    placeOfBirth: attributes["placeOfBirth"],
                    dateOfIssue: attributes["dateOfIssue"],
                    dateOfExpiration: attributes["dateOfExpiration"],
                    countryOfIssue: attributes["countryOfIssue"],
                    placeOfIssue: attributes["placeOfIssue"]
                )
            }

        case "Crew":
            if inCrewInfo {
                currentMember.department = attributes["department"]
                let rawDutyCode = attributes["dutyCode"] ?? ""
                currentMember.dutyCodeRaw = rawDutyCode
                currentMember.dutyCode = DutyCode(rawValue: rawDutyCode)
                currentMember.employeeId = attributes["employeeId"]
                currentMember.licenseNumber = attributes["licenseNumber"]
                let rawRank = attributes["rank"] ?? ""
                currentMember.rank = CrewRank(rawValue: rawRank)
                if let sen = attributes["seniority"] {
                    currentMember.seniority = Int(sen)
                }
            }

        case "Languages":
            inLanguages = true

        case "Qualifications":
            inQualifications = true

        case "ConnectionInfo":
            inConnectionInfo = true

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633SupplementaryHeader":
            inSuppHeader = false

        case "AirportICAOCode":
            if inSuppHeader && !inConnectionInfo {
                if inDepartureAirport { suppDepartureICAO = text }
                else if inArrivalAirport { suppArrivalICAO = text }
            }

        case "AirportIATACode":
            if inSuppHeader && !inConnectionInfo {
                if inDepartureAirport { suppDepartureIATA = text }
                else if inArrivalAirport { suppArrivalIATA = text }
            }

        case "AircraftICAOType", "AircraftIATAType":
            if inSuppHeader {
                suppAircraftType = text
            }

        case "FlightIdentifier":
            if inSuppHeader && !inConnectionInfo {
                suppFlightIdentifier = text
            }

        case "CommercialFlightNumber":
            if inSuppHeader && !inConnectionInfo {
                suppCommercialFlightNumber = text
            }

        case "DepartureAirport":
            if inSuppHeader && !inConnectionInfo {
                inDepartureAirport = false
            }

        case "ArrivalAirport":
            if inSuppHeader && !inConnectionInfo {
                inArrivalAirport = false
            }

        case "Gender":
            if inCrewInfo && inPersonalInfo {
                currentMember.gender = text
            }

        case "Language":
            if inCrewInfo && inLanguages {
                currentMember.languages.append(text)
            }

        case "Qualification":
            if inCrewInfo && inQualifications {
                currentMember.qualifications.append(text)
            }

        case "NonSmokingRoomRequest":
            if inCrewInfo {
                currentMember.nonSmokingRoomRequest = (text.lowercased() == "true")
            }

        case "Languages":
            inLanguages = false

        case "Qualifications":
            inQualifications = false

        case "ConnectionInfo":
            inConnectionInfo = false

        case "PersonalInfo":
            // Outer PersonalInfo closes -- still in CrewInfo
            break

        case "CrewInfo":
            result.members.append(currentMember)
            currentMember = CrewMember()
            inCrewInfo = false
            inPersonalInfo = false

        default:
            break
        }
    }

    // MARK: - Finalize

    private func finalizeHeaders() {
        result.header = ARINC633Header(
            versionNumber: headerVersionNumber,
            timestamp: headerTimestamp
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
