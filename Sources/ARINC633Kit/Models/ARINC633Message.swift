// ARINC633Message.swift
// ARINC633Kit
//
// Unified message type enum for all ARINC 633-4 message types.
// Root element detection dispatches to type-specific parsers.

import Foundation

/// All ARINC 633-4 message types that can be parsed, plus two open-ended cases.
///
/// Each ARINC 633-4 message type maps to one case carrying its fully-typed model.
/// Two cases keep the kit open:
/// - `.captured` — an unregistered root element preserved as a `CapturedElement` tree
///   (nothing is ever dropped).
/// - `.custom` — a payload produced by an integrator-registered handler (see
///   `ARINC633CustomMessage` and `ARINC633MessageRegistry`). The optional
///   `ARINC633KitSUPP` module uses this for Lido `AdditionalRemarks`.
///
/// Note: `AdditionalRemarks` is intentionally **not** a core case — it is a Lido/vendor
/// SUPP extension delivered via the `.custom` path by `ARINC633KitSUPP`.
public enum ARINC633Message: Sendable {
    case flightPlan(FlightPlan)
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
    case paxList(PaxList)
    case regionWeather(RegionWeatherBriefing)
    case upperAirData(UpperAirData)
    case airportData(AirportDataMessage)
    case generalError(GeneralError)

    /// An unregistered root element, preserved verbatim as a structured tree.
    case captured(CapturedElement)

    /// A payload from an integrator-registered custom handler.
    case custom(any ARINC633CustomMessage)
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
