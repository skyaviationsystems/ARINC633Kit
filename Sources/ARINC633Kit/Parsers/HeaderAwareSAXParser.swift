// HeaderAwareSAXParser.swift
// ARINC633Kit
//
// A SAX base parser that transparently extracts the ARINC 633 message envelope
// (`M633Header`/`M633LTDHeader` + `M633SupplementaryHeader`/`M633LTDSupplementaryHeader`)
// so concrete message parsers only implement their payload.
//
// Subclasses override `handlePayloadStart`/`handlePayloadEnd` (NOT the raw
// `handleStartElement`/`handleEndElement`, which this base reserves for envelope
// tracking and then forwards). After parsing, read `parsedHeader`,
// `parsedSupplementaryHeader`, `rootElementName`, and `rootAttributes`.

import Foundation

/// SAX base that captures the common ARINC 633 message envelope.
///
/// Header handling is centralized here (and hardened once): `versionNumber`,
/// `timestamp`, `FlightKeyIdentifier`, departure/arrival ICAO/IATA + `airportName`,
/// aircraft registration/type, and `airlineSpecificSubType`. Both the standard and
/// LTD header element variants are recognized.
open class HeaderAwareSAXParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Envelope results (read after parsing)

    /// The parsed `M633Header` / `M633LTDHeader`.
    public private(set) var parsedHeader = ARINC633Header()

    /// The parsed supplementary header (standard or LTD variant).
    public private(set) var parsedSupplementaryHeader = SupplementaryHeader()

    /// The document root element's local name.
    public private(set) var rootElementName = ""

    /// The document root element's attributes.
    public private(set) var rootAttributes: [String: String] = [:]

    /// True while inside the supplementary header (useful to subclasses to avoid
    /// mistaking envelope fields for payload).
    public private(set) var inSupplementaryHeader = false

    // MARK: - Header builder state

    private var hVersion = ""
    private var hTimestamp = ""
    private var hMessageSequence: String?
    private var fOriginDate: String?
    private var fSchedDeparture: String?
    private var fAirline = ""
    private var fNumber = ""
    private var fIdentifier: String?
    private var fCommercial: String?
    private var depICAO = ""
    private var depIATA: String?
    private var depName: String?
    private var arrICAO = ""
    private var arrIATA: String?
    private var arrName: String?
    private var acRegistration = ""
    private var acType: String?
    private var acSubType: String?
    private var flightKeyId: String?
    private var inDepartureAirport = false
    private var inArrivalAirport = false
    private var sawRoot = false

    // MARK: - Subclass override points

    /// Called for every start element NOT consumed by envelope handling.
    open func handlePayloadStart(_ elementName: String, attributes: [String: String]) {}

    /// Called for every end element NOT consumed by envelope handling, with text.
    open func handlePayloadEnd(_ elementName: String, text: String) {}

    // MARK: - SAXParserEngine

    public final override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        if !sawRoot {
            sawRoot = true
            rootElementName = elementName
            rootAttributes = attributes
            return
        }

        switch elementName {
        case "M633Header", "M633LTDHeader":
            hVersion = attributes["versionNumber"] ?? ""
            hTimestamp = attributes["timestamp"] ?? ""
            hMessageSequence = attributes["messageSequence"]
            return
        case "M633SupplementaryHeader", "M633LTDSupplementaryHeader":
            inSupplementaryHeader = true
            return
        default:
            break
        }

        if inSupplementaryHeader {
            switch elementName {
            case "Flight":
                fOriginDate = attributes["flightOriginDate"]
                fSchedDeparture = attributes["scheduledTimeOfDeparture"]
                return
            case "FlightNumber":
                fAirline = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
                fNumber = attributes["number"] ?? ""
                return
            case "DepartureAirport":
                inDepartureAirport = true; inArrivalAirport = false
                depName = attributes["airportName"]
                return
            case "ArrivalAirport":
                inArrivalAirport = true; inDepartureAirport = false
                arrName = attributes["airportName"]
                return
            case "Aircraft":
                acRegistration = attributes["aircraftRegistration"] ?? ""
                return
            case "AircraftModel":
                acSubType = attributes["airlineSpecificSubType"]
                return
            default:
                break
            }
        }

        handlePayloadStart(elementName, attributes: attributes)
    }

    public final override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633Header", "M633LTDHeader":
            parsedHeader = ARINC633Header(versionNumber: hVersion, timestamp: hTimestamp, messageSequence: hMessageSequence)
            return
        case "M633SupplementaryHeader", "M633LTDSupplementaryHeader":
            finalizeSupplementaryHeader()
            inSupplementaryHeader = false
            return
        default:
            break
        }

        if inSupplementaryHeader {
            switch elementName {
            case "FlightKeyIdentifier":
                flightKeyId = text.isEmpty ? nil : text; return
            case "FlightIdentifier":
                fIdentifier = text.isEmpty ? nil : text; return
            case "CommercialFlightNumber":
                fCommercial = text.isEmpty ? nil : text; return
            case "AirportICAOCode":
                if inDepartureAirport { depICAO = text } else if inArrivalAirport { arrICAO = text }
                return
            case "AirportIATACode":
                if inDepartureAirport { depIATA = text.isEmpty ? nil : text }
                else if inArrivalAirport { arrIATA = text.isEmpty ? nil : text }
                return
            case "AircraftICAOType", "AircraftIATAType":
                if acType == nil || elementName == "AircraftICAOType" { acType = text.isEmpty ? nil : text }
                return
            case "DepartureAirport":
                inDepartureAirport = false; return
            case "ArrivalAirport":
                inArrivalAirport = false; return
            default:
                break
            }
        }

        handlePayloadEnd(elementName, text: text)
    }

    private func finalizeSupplementaryHeader() {
        let flight = ARINCHeaderFlight(
            airlineCode: fAirline,
            flightNumber: fNumber,
            flightIdentifier: fIdentifier,
            commercialFlightNumber: fCommercial,
            departure: ARINCHeaderAirport(icaoCode: depICAO, iataCode: depIATA, name: depName),
            arrival: ARINCHeaderAirport(icaoCode: arrICAO, iataCode: arrIATA, name: arrName),
            scheduledDepartureTime: fSchedDeparture,
            flightOriginDate: fOriginDate
        )
        let aircraft = ARINCHeaderAircraft(registration: acRegistration, aircraftType: acType, engineType: acSubType)
        parsedSupplementaryHeader = SupplementaryHeader(flight: flight, aircraft: aircraft, flightKeyIdentifier: flightKeyId)
    }
}
