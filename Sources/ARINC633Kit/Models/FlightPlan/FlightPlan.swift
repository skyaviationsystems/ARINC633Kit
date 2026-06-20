// FlightPlan.swift
// ARINC633Kit
//
// Top-level FlightPlan model aggregating all 13 sections.

import Foundation

/// Parsed ARINC 633 FlightPlan message with all 13 sections.
///
/// Sections:
/// 1. header (M633Header)
/// 2. supplementaryHeader (M633SupplementaryHeader)
/// 3. flightPlanHeader (route, performance, MEL/CDL)
/// 4. fuelHeader (all fuel categories)
/// 5. weightHeader (ZFW, TOW, LDW)
/// 6. waypoints (main route navigation data)
/// 7. summary (OOOI times, totals)
/// 8. etopsSummary (critical fuel positions)
/// 9. alternateRoutes (alternate airport routes)
/// 10. airportData (airport details)
/// 11. contingencySaving (redispatch route with own fuel/waypoints)
/// 12. fuelStatistics (statistical fuel analysis)
/// 13. tankeringInfo (tankering economics)
///
/// Additional: terrainClearance, remarks, flightPlanId, captain, atcCallsign
public struct FlightPlan: Sendable, Equatable {
    // MARK: - Root attributes

    /// Flight plan ID from root element (e.g., "REV 5").
    public var flightPlanId: String?

    /// Computed time from root element.
    public var computedTime: String?

    /// Category from root element (e.g., "normal").
    public var category: String?

    /// Release valid-until time from root element (ISO 8601).
    public var validUntil: String?

    // MARK: - Headers

    /// ARINC 633 message header.
    public var header: ARINC633Header

    /// Supplementary header with flight and aircraft context.
    public var supplementaryHeader: SupplementaryHeader

    // MARK: - FlightInfo

    /// Captain name from FlightInfo.
    public var captain: String?

    /// ATC callsign from FlightInfo.
    public var atcCallsign: String?

    /// SELCAL code from FlightInfo (e.g., "MREP").
    public var selcal: String?

    /// Crew list from FlightInfo (633-5 embedded crew data).
    public var crewList: [FlightPlanCrewMember]

    // MARK: - 13 Sections

    /// Section 3: Flight plan header (route, performance, MEL/CDL).
    public var flightPlanHeader: FlightPlanHeader?

    /// Section 4: Fuel header (all fuel categories).
    public var fuelHeader: FuelHeader?

    /// Section 5: Weight header (ZFW, TOW, LDW with limits).
    public var weightHeader: WeightHeader?

    /// Section 5 (convenience): Flat weight data extracted from weightHeader.
    public var weightData: WeightData?

    /// Section 6: Main route waypoints.
    public var waypoints: [Waypoint]

    /// Section 7: Flight plan summary (OOOI times, block/flight time).
    public var summary: FlightPlanSummary?

    /// Section 8: ETOPS summary (critical fuel positions).
    public var etopsSummary: ETOPSSummary?

    /// Section 9: Alternate routes with their own waypoints.
    public var alternateRoutes: [AlternateRoute]

    /// Section 10: Airport data list.
    public var airportData: [AirportData]

    /// Section 11: Contingency saving route (own fuel header + waypoints).
    public var contingencySaving: ContingencySaving?

    /// Section 12: Fuel statistics.
    public var fuelStatistics: FuelStatistics?

    /// Section 13: Tankering information.
    public var tankeringInfo: TankeringInfo?

    /// Terrain clearance data.
    public var terrainClearance: TerrainClearance?

    /// Top-level remarks (from <Remarks> before FlightPlanHeader).
    public var remarks: [FlightPlanRemark]

    /// Non-standard flight planning type (e.g., "reclearance").
    public var contingencySavingType: String?

    public init() {
        self.header = ARINC633Header()
        self.supplementaryHeader = SupplementaryHeader()
        self.waypoints = []
        self.alternateRoutes = []
        self.airportData = []
        self.remarks = []
        self.crewList = []
    }
}
