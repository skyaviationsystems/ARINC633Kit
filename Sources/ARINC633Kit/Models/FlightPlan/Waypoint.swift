// Waypoint.swift
// ARINC633Kit
//
// Navigation data per waypoint from <Waypoints>.

import Foundation

/// Wind measurement with direction and speed.
public struct ARINCWind: Sendable, Equatable {
    /// Wind direction in degrees.
    public let direction: Double

    /// Wind speed.
    public let speed: ARINCSpeed

    /// Direction type (e.g., "true", "magnetic").
    public let type: String

    public init(direction: Double, speed: ARINCSpeed, type: String = "true") {
        self.direction = direction
        self.speed = speed
        self.type = type
    }
}

/// A single waypoint in the flight plan route.
public struct Waypoint: Sendable, Equatable {
    /// Waypoint name (e.g., "KMIA", "DOLIE", "YXS").
    public var name: String

    /// Country ICAO code prefix (e.g., "K7" for US).
    public var countryICAOCode: String?

    /// Waypoint identifier.
    public var waypointId: String?

    /// Sequence ID in the route.
    public var sequenceId: Int

    /// Geographic coordinate.
    public var coordinate: ARINCCoordinate?

    /// Airway name (e.g., "Y280", "DCT").
    public var airway: String?

    /// Functions of this waypoint (DepartureAirport, Enroute, etc.).
    public var functions: [WaypointFunction]

    /// Altitude (estimated/actual).
    public var altitude: EstimatedActual<ARINCAltitude>

    /// Minimum safe altitude.
    public var minimumSafeAltitude: ARINCAltitude?

    /// Tropopause altitude.
    public var tropopause: ARINCAltitude?

    /// Wind at this waypoint.
    public var wind: ARINCWind?

    /// Wind component (positive = tailwind, negative = headwind).
    public var windComponent: ARINCSpeed?

    /// Temperature.
    public var temperature: ARINCTemperature?

    /// ISA deviation.
    public var isaDeviation: ARINCTemperature?

    /// True air speed.
    public var trueAirSpeed: EstimatedActual<ARINCSpeed>

    /// Mach number.
    public var mach: EstimatedActual<ARINCMachNumber>

    /// Indicated air speed.
    public var indicatedAirSpeed: EstimatedActual<ARINCSpeed>

    /// Ground speed.
    public var groundSpeed: EstimatedActual<ARINCSpeed>

    /// Outbound true track (degrees).
    public var outboundTrueTrack: Double?

    /// Outbound magnetic track (degrees).
    public var outboundMagneticTrack: Double?

    /// Segment true track (degrees).
    public var segmentTrueTrack: Double?

    /// Segment magnetic track (degrees).
    public var segmentMagneticTrack: Double?

    /// Ground distance for this segment.
    public var groundDistance: ARINCDistance?

    /// Remaining ground distance.
    public var remainingGroundDistance: ARINCDistance?

    /// Air distance for this segment.
    public var airDistance: ARINCDistance?

    /// Remaining air distance.
    public var remainingAirDistance: ARINCDistance?

    /// Time from previous waypoint.
    public var timeFromPrevious: ARINC633Duration?

    /// Time over waypoint (ISO 8601 datetime string).
    public var timeOverWaypoint: String?

    /// Cumulated flight time.
    public var cumulatedFlightTime: ARINC633Duration?

    /// Remaining flight time.
    public var remainingFlightTime: ARINC633Duration?

    /// Burn off (fuel consumed in this segment).
    public var burnOff: EstimatedActual<ARINCWeight>

    /// Cumulated burn off.
    public var cumulatedBurnOff: EstimatedActual<ARINCWeight>

    /// Fuel on board at this waypoint.
    public var fuelOnBoard: EstimatedActual<ARINCWeight>

    /// Minimum fuel on board.
    public var minimumFuel: ARINCWeight?

    /// Flight information region.
    public var flightInformationRegion: String?

    /// Airspace identifier.
    public var airspaceIdentifier: String?

    /// Frequency.
    public var frequency: String?

    /// Inbound true track (degrees).
    public var inboundTrueTrack: Double?

    /// Inbound magnetic track (degrees).
    public var inboundMagneticTrack: Double?

    /// Magnetic variation at this waypoint (degrees).
    public var magneticVariation: Double?

    /// Maximum terrain elevation for the segment from this waypoint.
    public var maximumTerrainElevation: ARINCAltitude?

    /// Minimum vertical clearance above terrain.
    public var minimumVerticalClearance: ARINCAltitude?

    /// Maximum segment turbulence EDR value.
    public var maximumSegmentTurbulence: Double?

    /// Required Navigation Performance value.
    public var rnp: Double?

    /// Navaid frequencies at this waypoint.
    public var navaidFrequencies: [Double]

    /// Airspace traversals for this waypoint segment.
    public var airspaceTraversals: [AirspaceTraversal]

    /// Safe altitudes for diversion routes (from ETOPS terrain avoidance).
    public var safeAltitudes: [SafeAltitude]

    /// The primary function of this waypoint.
    public var function: WaypointFunction {
        functions.first ?? .unknown("")
    }

    public init(name: String = "", sequenceId: Int = 0) {
        self.name = name
        self.sequenceId = sequenceId
        self.functions = []
        self.altitude = EstimatedActual()
        self.trueAirSpeed = EstimatedActual()
        self.mach = EstimatedActual()
        self.indicatedAirSpeed = EstimatedActual()
        self.groundSpeed = EstimatedActual()
        self.burnOff = EstimatedActual()
        self.cumulatedBurnOff = EstimatedActual()
        self.fuelOnBoard = EstimatedActual()
        self.navaidFrequencies = []
        self.airspaceTraversals = []
        self.safeAltitudes = []
    }
}

/// An airspace traversal entry for a waypoint.
public struct AirspaceTraversal: Sendable, Equatable {
    /// Airspace name (e.g., "FORT WORTH ARTCC", "USA").
    public let airspaceName: String

    /// Airspace ICAO code (e.g., "KZFW").
    public let airspaceICAOCode: String?

    /// Airspace type (e.g., "FIRUIR", "COUNTRY", "ADHOC").
    public let airspaceType: String?

    /// Transition type (e.g., "ENTRY", "EXIT", "DEPARTURE", "DESTINATION").
    public let transition: String?

    /// Ground distance within this airspace segment.
    public let distanceWithin: ARINCDistance?

    /// Ground distance to airspace entry point.
    public let distanceToEntry: ARINCDistance?

    /// Ground distance to airspace exit point.
    public let distanceToExit: ARINCDistance?

    public init(
        airspaceName: String,
        airspaceICAOCode: String? = nil,
        airspaceType: String? = nil,
        transition: String? = nil,
        distanceWithin: ARINCDistance? = nil,
        distanceToEntry: ARINCDistance? = nil,
        distanceToExit: ARINCDistance? = nil
    ) {
        self.airspaceName = airspaceName
        self.airspaceICAOCode = airspaceICAOCode
        self.airspaceType = airspaceType
        self.transition = transition
        self.distanceWithin = distanceWithin
        self.distanceToEntry = distanceToEntry
        self.distanceToExit = distanceToExit
    }
}

/// A safe altitude entry from a diversion route terrain avoidance section.
public struct SafeAltitude: Sendable, Equatable {
    /// Method or constraint description (e.g., "isWithinDistance").
    public let method: String?

    /// Safe altitude value.
    public let altitude: ARINCAltitude

    /// Great circle distance from airport for this safe altitude band.
    public let greatCircleDistanceFromAirport: ARINCDistance?

    public init(method: String?, altitude: ARINCAltitude, greatCircleDistanceFromAirport: ARINCDistance? = nil) {
        self.method = method
        self.altitude = altitude
        self.greatCircleDistanceFromAirport = greatCircleDistanceFromAirport
    }
}
