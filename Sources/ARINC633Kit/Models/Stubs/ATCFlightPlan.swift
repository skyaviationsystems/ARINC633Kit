// ATCFlightPlan.swift
// ARINC633Kit
//
// ATC ICAO Flight Plan model.
// Based on FlightPlanAtcIcao.xsd schema.
// Parses M633Header, M633SupplementaryHeader, AtcMessageText, and AtcMessageDetails
// including ICAO ATC flight plan Items 7-18.

import Foundation

/// ATC ICAO flight plan message parsed from `<FlightPlanAtcIcao>`.
public struct ATCFlightPlan: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Flight plan ID reference (legacy).
    public let flightPlanId: String?

    /// Raw ATC message text from `<AtcMessageText>/<Paragraph>/<Text>`.
    public let rawContent: String?

    // MARK: - AtcMessageDetails

    /// ATC message type (e.g., "FPL", "CHG").
    public let messageType: String?

    /// ATC message priority (e.g., "FF", "SS").
    public let messagePriority: String?

    // MARK: - Item 7: Aircraft Identification

    /// ATC callsign from Item7 (e.g., "GTI606").
    public let callsign: String?

    // MARK: - Item 8: Flight Rules and Type of Flight

    /// Flight rules from Item8 (e.g., "I" for IFR, "V" for VFR).
    public let flightRules: String?

    /// Type of flight from Item8 (e.g., "S" for scheduled, "N" for non-scheduled).
    public let typeOfFlight: String?

    // MARK: - Item 9: Number and Type of Aircraft

    /// ICAO aircraft type designator from Item9 (e.g., "B772").
    public let aircraftType: String?

    /// Wake turbulence category from Item9 (e.g., "H" for heavy).
    public let wakeTurbulence: String?

    // MARK: - Item 10: Equipment

    /// Aircraft equipment and capabilities from Item10 (e.g., "DE1FGHIM1RSWXYZ/LB1").
    public let aircraftEquipment: String?

    // MARK: - Item 13: Departure Aerodrome and Time

    /// Departure airport ICAO code from Item13 (e.g., "ELLX").
    public let departureAirport: String?

    /// Departure time (HHMM UTC) from Item13 (e.g., "1735").
    public let departureTime: String?

    // MARK: - Item 15: Route

    /// Cruising speed from Item15 (e.g., "N0486" = 486 knots).
    public let cruisingSpeed: String?

    /// Cruising level from Item15 (e.g., "F280" = FL280).
    public let cruisingLevel: String?

    /// Route string from Item15.
    public let route: String?

    // MARK: - Item 16: Destination and Alternate

    /// Arrival airport ICAO code from Item16 (e.g., "KHSV").
    public let arrivalAirport: String?

    /// Estimated total elapsed time from Item16 (e.g., "0904" = 9h04m).
    public let estimatedFlightTime: String?

    /// First alternate airport ICAO code from Item16 (e.g., "KBHM").
    public let alternateAirport: String?

    // MARK: - Item 18: Other Information

    /// Item 18 sub-elements as key-value pairs.
    /// Keys include PBN, NAV, DAT, SUR, DOF, REG, SEL, CODE, OPR, RMK, etc.
    public let item18: [String: String]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                flightPlanId: String? = nil,
                rawContent: String? = nil,
                messageType: String? = nil,
                messagePriority: String? = nil,
                callsign: String? = nil,
                flightRules: String? = nil,
                typeOfFlight: String? = nil,
                aircraftType: String? = nil,
                wakeTurbulence: String? = nil,
                aircraftEquipment: String? = nil,
                departureAirport: String? = nil,
                departureTime: String? = nil,
                cruisingSpeed: String? = nil,
                cruisingLevel: String? = nil,
                route: String? = nil,
                arrivalAirport: String? = nil,
                estimatedFlightTime: String? = nil,
                alternateAirport: String? = nil,
                item18: [String: String] = [:]) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.flightPlanId = flightPlanId
        self.rawContent = rawContent
        self.messageType = messageType
        self.messagePriority = messagePriority
        self.callsign = callsign
        self.flightRules = flightRules
        self.typeOfFlight = typeOfFlight
        self.aircraftType = aircraftType
        self.wakeTurbulence = wakeTurbulence
        self.aircraftEquipment = aircraftEquipment
        self.departureAirport = departureAirport
        self.departureTime = departureTime
        self.cruisingSpeed = cruisingSpeed
        self.cruisingLevel = cruisingLevel
        self.route = route
        self.arrivalAirport = arrivalAirport
        self.estimatedFlightTime = estimatedFlightTime
        self.alternateAirport = alternateAirport
        self.item18 = item18
    }
}
