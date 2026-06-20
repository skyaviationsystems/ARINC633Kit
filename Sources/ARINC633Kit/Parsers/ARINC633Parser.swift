// ARINC633Parser.swift
// ARINC633Kit
//
// Unified entry point for ARINC 633 XML parsing.
// Detects message type from root element, dispatches to type-specific parsers.

import Foundation

/// Unified entry point for parsing any ARINC 633-4 XML message.
///
/// Usage:
/// ```swift
/// let parser = ARINC633Parser()
/// let message = try parser.parse(data: xmlData)
/// ```
///
/// The parser performs two passes:
/// 1. Quick root element detection via `RootElementDetector`
/// 2. Dispatch to type-specific parser based on root element name
public final class ARINC633Parser: Sendable {

    public init() {}

    /// Parse an ARINC 633 XML document and return the typed message.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: The parsed message type
    /// - Throws: `ARINC633ParseError` on failure
    public func parse(data: Data) throws -> ARINC633Message {
        // First pass: detect root element name
        let detector = RootElementDetector()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = detector
        xmlParser.shouldProcessNamespaces = true
        xmlParser.parse()

        guard let rootElement = detector.rootElement else {
            throw ARINC633ParseError.emptyDocument
        }

        // Dispatch based on root element to type-specific parsers
        switch rootElement {
        // -- Full domain parsers --
        case "FlightPlan":
            let parser = FlightPlanParser()
            let flightPlan = try parser.parse(data: data)
            return .flightPlan(flightPlan)

        case "AdditionalRemarks":
            let parser = AdditionalRemarksParser()
            let remarks = try parser.parse(data: data)
            return .additionalRemarks(remarks)

        case "LoadAndTrimData":
            let parser = LoadAndTrimDataParser()
            let ltd = try parser.parse(data: data)
            return .loadAndTrimData(ltd)

        case "AirportWeather":
            let parser = AirportWeatherParser()
            let weather = try parser.parse(data: data)
            return .airportWeather(weather)

        case "CrewList":
            let parser = CrewListParser()
            let crew = try parser.parse(data: data)
            return .crewList(crew)

        // -- EFF parser (EFUSUB / EFDREP) --
        case "EFUSUB", "EFDREP":
            let parser = EFFParser()
            let eff = try parser.parse(data: data)
            return .eff(eff)

        // -- Full domain parser for NOTAMBriefing --
        case "NOTAMBriefing":
            let parser = NOTAMBriefingParser()
            let briefing = try parser.parse(data: data)
            return .notam(briefing)

        case "ATIS":
            let (header, suppHeader, _, _) = try parseStub(data: data)
            return .atis(ATISMessage(header: header, supplementaryHeader: suppHeader))

        case "FlightPlanAtcIcao":
            let parser = ATCFlightPlanParser()
            let atcPlan = try parser.parse(data: data)
            return .atcFlightPlan(atcPlan)

        case "RAIMReport":
            let (header, suppHeader, _, _) = try parseStub(data: data)
            return .raimReport(RAIMReport(header: header, supplementaryHeader: suppHeader))

        case "PIREPBriefing":
            let (header, suppHeader, attrs, _) = try parseStub(data: data)
            return .pirepBriefing(PIREPBriefing(
                header: header,
                supplementaryHeader: suppHeader,
                creationTime: attrs["creationTime"],
                fullPackage: attrs["fullPackage"] == "true"
            ))

        case "HazardBriefing":
            let (header, suppHeader, _, _) = try parseStub(data: data)
            return .hazardBriefing(HazardBriefing(header: header, supplementaryHeader: suppHeader))

        case "OrganizedTracks":
            let (header, suppHeader, attrs, _) = try parseStub(data: data)
            return .organizedTracks(OrganizedTracksMessage(
                header: header,
                supplementaryHeader: suppHeader,
                trackMessageIdentifier: attrs["trackMessageIdentifier"],
                area: attrs["area"]
            ))

        case "AirspaceData":
            let (header, suppHeader, _, _) = try parseStub(data: data)
            return .airspaceData(AirspaceDataMessage(header: header, supplementaryHeader: suppHeader))

        // -- WBA message types (Weight & Balance Amendment) --
        case "WIFSUB", "WIISUB", "WIMSUB", "WIRREP":
            let (header, suppHeader, _, root) = try parseStub(data: data)
            return .wba(WBAMessage(
                header: header,
                supplementaryHeader: suppHeader,
                messageSubtype: root
            ))

        // -- FUEL message types (Refueling / CG Targeting) --
        case "FCAIND", "FDAACK", "FDACOM", "FDASUB", "FENIND", "FERIND",
             "FORACK", "FORSUB", "FPRREP", "FRCACK", "FRCSUB", "FSTREP",
             "FSTREQ", "FTBIND", "FTEIND", "FTIIND":
            let (header, suppHeader, _, root) = try parseStub(data: data)
            return .fuel(FUELMessage(
                header: header,
                supplementaryHeader: suppHeader,
                messageSubtype: root
            ))

        // -- De-Icing message types --
        case "DORACK", "DORIND", "DORSUB", "DPRREP", "DRCACK", "DRCSUB":
            let (header, suppHeader, _, root) = try parseStub(data: data)
            return .deIcing(DeIcingMessage(
                header: header,
                supplementaryHeader: suppHeader,
                messageSubtype: root
            ))

        // -- Generic stub types --
        case "PaxList":
            return try parseGenericStub(data: data, case: { .paxList($0) })

        case "RegionWeather", "RegionWeatherBriefing":
            return try parseGenericStub(data: data, case: { .regionWeather($0) })

        case "UpperAirData":
            return try parseGenericStub(data: data, case: { .upperAirData($0) })

        case "AirportData":
            return try parseGenericStub(data: data, case: { .airportData($0) })

        // -- General error message (GERIND) --
        case "GERIND":
            return try parseGenericStub(data: data, case: { .generalError($0) })

        default:
            return .unknown(rootElement)
        }
    }

    // MARK: - Stub Parsing Helpers

    /// Parse using StubParser and return header information.
    private func parseStub(data: Data) throws -> (ARINC633Header, SupplementaryHeader, [String: String], String) {
        let parser = StubParser()
        return try parser.parse(data: data)
    }

    /// Parse a generic stub message and wrap it in the given case constructor.
    private func parseGenericStub(data: Data, case constructor: (StubMessage) -> ARINC633Message) throws -> ARINC633Message {
        let (header, suppHeader, attrs, root) = try parseStub(data: data)
        let stub = StubMessage(
            header: header,
            supplementaryHeader: suppHeader,
            rootElement: root,
            rootAttributes: attrs
        )
        return constructor(stub)
    }
}

// MARK: - Root Element Detector

/// Lightweight SAX parser that captures the root element name and stops.
final class RootElementDetector: NSObject, XMLParserDelegate, @unchecked Sendable {
    /// The detected root element name.
    var rootElement: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if rootElement == nil {
            rootElement = elementName
            parser.abortParsing()
        }
    }
}
