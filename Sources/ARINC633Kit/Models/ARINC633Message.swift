// ARINC633Message.swift
// ARINC633Kit
//
// Unified message type enum for all ARINC 633-4 message types.
// Root element detection dispatches to type-specific parsers.

import Foundation

/// All ARINC 633-4 message types that can be parsed.
///
/// FlightPlan, LoadAndTrimData, AirportWeather, CrewList, and EFF include fully parsed associated data.
/// Remaining types carry header information via StubParser with rawContent for future full parsing.
public enum ARINC633Message: Sendable {
    case flightPlan(FlightPlan)
    case additionalRemarks(AdditionalRemarks)
    case loadAndTrimData(LoadAndTrimData)
    case airportWeather(AirportWeather)
    case crewList(CrewList)
    case eff(EFF)
    case notam(NOTAMBriefing)
    case atis(ATISMessage)
    case atcFlightPlan(ATCFlightPlan)
    case raimReport(RAIMReport)
    case pirepBriefing(PIREPBriefing)
    case hazardBriefing(HazardBriefing)
    case organizedTracks(OrganizedTracksMessage)
    case airspaceData(AirspaceDataMessage)
    case wba(WBAMessage)
    case fuel(FUELMessage)
    case deIcing(DeIcingMessage)
    case paxList(StubMessage)
    case regionWeather(StubMessage)
    case upperAirData(StubMessage)
    case airportData(StubMessage)
    case generalError(StubMessage)
    case unknown(String)
}

/// Generic stub message for types without dedicated model structs.
/// Carries header information extracted by StubParser.
public struct StubMessage: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Root element name identifying the message subtype.
    public let rootElement: String

    /// Root element attributes.
    public let rootAttributes: [String: String]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                rootElement: String = "",
                rootAttributes: [String: String] = [:]) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.rootElement = rootElement
        self.rootAttributes = rootAttributes
    }
}

/// Errors that can occur during ARINC 633 parsing.
public enum ARINC633ParseError: Error, Sendable {
    /// The document is empty or has no root element.
    case emptyDocument

    /// XMLParser reported an error.
    case xmlParserError(String)

    /// The root element doesn't match any known message type.
    case unsupportedMessageType(String)
}
