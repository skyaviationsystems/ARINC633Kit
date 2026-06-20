// AirspaceData.swift
// ARINC633Kit
//
// Typed model for the AirspaceData message (root <AirspaceData>, AirspaceData.xsd).
//
// Structure: <AirspaceData> carries an optional flight-plan identifier and one or more
// <Airspace> volumes the flight crosses. Each <Airspace> describes the volume (ICAO
// code, name, type) and, where available, the geometry/timing of the crossing: an
// <Entry> and <Exit> border point, great-circle and ground distance across the volume,
// en-route charges, and overflight-permit status. Border points carry coordinates,
// cumulated ground distance / flight time from takeoff, and an optional nearest
// waypoint. Coordinates are encoded in arc-seconds (see ARINCCoordinate).

import Foundation

/// A parsed AirspaceData message: the airspace volumes a flight crosses, in order.
public struct AirspaceDataMessage: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context (`<M633SupplementaryHeader>`).
    public let supplementaryHeader: SupplementaryHeader

    /// Identifier of the operational flight plan (`@flightPlanId`, optional).
    public var flightPlanId: String?

    /// The airspace volumes crossed, in best display order (`<Airspace>`, maxOccurs unbounded).
    public var airspaces: [Airspace]

    /// Unrecognized top-level payload children preserved verbatim (vendor extensions).
    public var extensions: [CapturedElement]

    /// Backward-compatible initializer. New payload parameters default to empty/nil so
    /// existing call sites (registry, tests) keep compiling.
    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                flightPlanId: String? = nil,
                airspaces: [Airspace] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.flightPlanId = flightPlanId
        self.airspaces = airspaces
        self.extensions = extensions
    }
}

/// A single airspace volume crossed by the flight (`<Airspace>`).
public struct Airspace: Sendable, Equatable {
    /// ICAO code of the airspace, e.g. an FIR/UIR identifier (`@airspaceICAOCode`, optional).
    public var airspaceICAOCode: String?
    /// Human-readable airspace name (`@airspaceName`, optional).
    public var airspaceName: String?
    /// Airspace type/class free-text, e.g. "FIR", "UIR", restricted-area descriptors
    /// (`@airspaceType`, optional).
    public var airspaceType: String?
    /// Display ordering hint, typically ordered along the flight (`@sequence`, optional).
    public var sequence: String?

    /// Border point where the flight enters the volume (`<Entry>`, minOccurs=0).
    public var entry: AirspaceBorderPoint?
    /// Border point where the flight exits the volume (`<Exit>`, minOccurs=0).
    public var exit: AirspaceBorderPoint?

    /// Great-circle distance between entry and exit points (`<GreatCircleDistance>`, minOccurs=0).
    public var greatCircleDistance: ARINCDistance?
    /// Ground (flown) distance between entry and exit points (`<GroundDistance>`, minOccurs=0).
    public var groundDistance: ARINCDistance?

    /// En-route charges for crossing this volume (`<EnrouteChargesInformation>`, minOccurs=0).
    public var enrouteCharges: EnrouteChargesInformation?
    /// Overflight-permit status for this volume (`<OverflightPermitInformation>`, minOccurs=0).
    public var overflightPermit: OverflightPermitInformation?

    /// Unrecognized child elements preserved verbatim (vendor extensions, `<xs:any>`).
    public var extensions: [CapturedElement]

    public init(airspaceICAOCode: String? = nil,
                airspaceName: String? = nil,
                airspaceType: String? = nil,
                sequence: String? = nil,
                entry: AirspaceBorderPoint? = nil,
                exit: AirspaceBorderPoint? = nil,
                greatCircleDistance: ARINCDistance? = nil,
                groundDistance: ARINCDistance? = nil,
                enrouteCharges: EnrouteChargesInformation? = nil,
                overflightPermit: OverflightPermitInformation? = nil,
                extensions: [CapturedElement] = []) {
        self.airspaceICAOCode = airspaceICAOCode
        self.airspaceName = airspaceName
        self.airspaceType = airspaceType
        self.sequence = sequence
        self.entry = entry
        self.exit = exit
        self.greatCircleDistance = greatCircleDistance
        self.groundDistance = groundDistance
        self.enrouteCharges = enrouteCharges
        self.overflightPermit = overflightPermit
        self.extensions = extensions
    }
}

/// An airspace entry/exit border point (`BorderPointType`, used by `<Entry>` / `<Exit>`).
public struct AirspaceBorderPoint: Sendable, Equatable {
    /// Geographic position of the border point (`<Coordinates>`, minOccurs=0).
    /// Latitude/longitude attributes are in arc-seconds; converted to decimal degrees.
    public var coordinates: ARINCCoordinate?
    /// Cumulated ground distance from takeoff to this point (`<CumulatedGroundDistance>`, minOccurs=0).
    public var cumulatedGroundDistance: ARINCDistance?
    /// Cumulated flight time from takeoff to this point, ISO-8601 duration text
    /// (`@cumulatedFlightTime`, e.g. "PT10M40S", optional).
    public var cumulatedFlightTime: String?
    /// Nearest published waypoint to this border point (`<NearestWaypoint>`, minOccurs=0).
    public var nearestWaypoint: AirspaceWaypoint?

    /// Unrecognized child elements preserved verbatim (vendor extensions, `<xs:any>`).
    public var extensions: [CapturedElement]

    public init(coordinates: ARINCCoordinate? = nil,
                cumulatedGroundDistance: ARINCDistance? = nil,
                cumulatedFlightTime: String? = nil,
                nearestWaypoint: AirspaceWaypoint? = nil,
                extensions: [CapturedElement] = []) {
        self.coordinates = coordinates
        self.cumulatedGroundDistance = cumulatedGroundDistance
        self.cumulatedFlightTime = cumulatedFlightTime
        self.nearestWaypoint = nearestWaypoint
        self.extensions = extensions
    }
}

/// The nearest published waypoint to a border point (`<NearestWaypoint>`).
public struct AirspaceWaypoint: Sendable, Equatable {
    /// FMC waypoint code, 1..5 chars (`@waypointId`, optional).
    public var waypointId: String?
    /// Waypoint name as typically in ATC-FPL, or artificial name e.g. TOC/TOD
    /// (`@waypointName`, optional).
    public var waypointName: String?
    /// Country ICAO code of the waypoint (`@countryICAOCode`, optional).
    public var countryICAOCode: String?
    /// Waypoint position (`<Coordinates>`, minOccurs=0); arc-seconds -> decimal degrees.
    public var coordinates: ARINCCoordinate?
    /// Waypoint function/role free-text, e.g. "Airport", "EnrouteWaypoint"
    /// (`<Function>`, minOccurs=0).
    public var function: String?

    public init(waypointId: String? = nil,
                waypointName: String? = nil,
                countryICAOCode: String? = nil,
                coordinates: ARINCCoordinate? = nil,
                function: String? = nil) {
        self.waypointId = waypointId
        self.waypointName = waypointName
        self.countryICAOCode = countryICAOCode
        self.coordinates = coordinates
        self.function = function
    }
}

/// En-route charges levied for crossing an airspace (`<EnrouteChargesInformation>`).
public struct EnrouteChargesInformation: Sendable, Equatable {
    /// Distance calculation method, "GCD" (great-circle) or "FLOWN" (`@distanceMethod`, default "GCD").
    public var distanceMethod: String?
    /// ISO currency code the charge is paid in to the charging entity (`@localCurrency`, 3 chars).
    public var localCurrency: String?
    /// Charge amount in the local currency (`@amountInLocalCurrency`, optional).
    public var amountInLocalCurrency: Double?
    /// Unified ISO currency code allowing charges to be summed (`@unifiedCurrency`, 3 chars).
    public var unifiedCurrency: String?
    /// Charge amount in the unified currency (`@amountInUnifiedCurrency`, optional).
    public var amountInUnifiedCurrency: Double?

    public init(distanceMethod: String? = nil,
                localCurrency: String? = nil,
                amountInLocalCurrency: Double? = nil,
                unifiedCurrency: String? = nil,
                amountInUnifiedCurrency: Double? = nil) {
        self.distanceMethod = distanceMethod
        self.localCurrency = localCurrency
        self.amountInLocalCurrency = amountInLocalCurrency
        self.unifiedCurrency = unifiedCurrency
        self.amountInUnifiedCurrency = amountInUnifiedCurrency
    }
}

/// Overflight-permit status for an airspace (`<OverflightPermitInformation>`).
public struct OverflightPermitInformation: Sendable, Equatable {
    /// The overflight permit identifier (`@permitId`, optional).
    public var permitId: String?
    /// Whether an overflight permit is required for this airspace (`@isPermitRequired`, optional).
    public var isPermitRequired: Bool?

    public init(permitId: String? = nil, isPermitRequired: Bool? = nil) {
        self.permitId = permitId
        self.isPermitRequired = isPermitRequired
    }
}
