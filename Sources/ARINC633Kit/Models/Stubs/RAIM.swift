// RAIM.swift
// ARINC633Kit
//
// Typed model for the RAIMReport (Receiver Autonomous Integrity Monitoring prediction)
// message. Source: RAIMReport.xsd (root <RAIMReport>), RAIM.xsd (shared complex types),
// samples RAIMReport_1..2.xml.
//
// Structure: <RAIMReport> carries a required <GNSSReceiver> describing the receiver used
// for the predictions, then optional <RAIMAirportPredictions> (spot predictions per
// airport / integrity level) and optional <RAIMTrajectoryPredictions> (predictions along
// flight trajectories). Physical quantities such as airport elevation are encoded as
// <Value unit="..."> and surfaced via Foundation measurement types.

import Foundation

/// A parsed RAIMReport message: GNSS/RAIM integrity predictions for airports and/or
/// trajectories (root `<RAIMReport>`, RAIMReport.xsd).
public struct RAIMReport: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Report creation time (`@creationTime`, xs:dateTime, required), kept as ISO 8601 text.
    public var creationTime: String?

    /// Whether this is a complete package vs. an update to merge (`@fullPackage`, xs:boolean, required).
    public var fullPackage: Bool?

    /// Parameters of the GNSS receiver used in the predictions (`<GNSSReceiver>`, required).
    public var receiver: GNSSReceiver?

    /// Per-airport spot predictions (`<RAIMAirportPredictions>/<RAIMAirportPrediction>`, minOccurs=0).
    public var airportPredictions: [RAIMAirportPrediction]

    /// Per-trajectory predictions (`<RAIMTrajectoryPredictions>/<RAIMTrajectoryPrediction>`, minOccurs=0).
    public var trajectoryPredictions: [RAIMTrajectoryPrediction]

    /// Unrecognized top-level payload children preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    /// Backward-compatible designated initializer. Existing callers using only
    /// `header`/`supplementaryHeader` continue to compile; new fields default to empty.
    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                creationTime: String? = nil,
                fullPackage: Bool? = nil,
                receiver: GNSSReceiver? = nil,
                airportPredictions: [RAIMAirportPrediction] = [],
                trajectoryPredictions: [RAIMTrajectoryPrediction] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.receiver = receiver
        self.airportPredictions = airportPredictions
        self.trajectoryPredictions = trajectoryPredictions
        self.extensions = extensions
    }
}

/// Parameters of the GNSS receiver used for the predictions (`<GNSSReceiver>`,
/// GNSSReceiverType in m633common.xsd).
public struct GNSSReceiver: Sendable, Equatable {
    /// Receiver type designator (`@type`, xs:string, e.g. "145146").
    public var type: String?
    /// Integrity algorithm (`@algorithm`, required): "FD" (Fault Detection) or
    /// "FDE" (Fault Detection and Exclusion).
    public var algorithm: String?
    /// Selective Availability assumption (`@sa`, xs:boolean, required): true=SA assumed ON.
    public var selectiveAvailability: Bool?
    /// Whether barometric aiding is used (`@baroAiding`, xs:boolean, required).
    public var baroAiding: Bool?
    /// Receiver mask angle in degrees (`@maskAngle`, xs:double, required).
    public var maskAngle: Double?

    public init(type: String? = nil,
                algorithm: String? = nil,
                selectiveAvailability: Bool? = nil,
                baroAiding: Bool? = nil,
                maskAngle: Double? = nil) {
        self.type = type
        self.algorithm = algorithm
        self.selectiveAvailability = selectiveAvailability
        self.baroAiding = baroAiding
        self.maskAngle = maskAngle
    }
}

/// Geographical coordinates (`coordinateType.grp`): latitude/longitude in seconds,
/// positive = North/East, negative = South/West.
public struct RAIMCoordinates: Sendable, Equatable {
    /// Latitude in seconds (`@latitude`, required in schema, range -324000..324000).
    public var latitude: Double?
    /// Longitude in seconds (`@longitude`, required in schema, range -648000..648000).
    public var longitude: Double?
    /// Local magnetic variation in degrees (`@magneticVariation`, optional, range -180..180).
    public var magneticVariation: Double?

    public init(latitude: Double? = nil, longitude: Double? = nil, magneticVariation: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.magneticVariation = magneticVariation
    }
}

/// Time-range parameters for a spot prediction (`<TimeRangeParameters>`,
/// TimeRangeParametersType in RAIM.xsd).
public struct RAIMTimeRange: Sendable, Equatable {
    /// Inclusive start of the prediction window (`@begin`, xs:dateTime), kept as text.
    public var begin: String?
    /// Sample period (`@samplePeriod`, xs:duration, e.g. "PT1M"), kept as text.
    public var samplePeriod: String?
    /// Inclusive end of the prediction window (`@end`, xs:dateTime), kept as text.
    public var end: String?

    public init(begin: String? = nil, samplePeriod: String? = nil, end: String? = nil) {
        self.begin = begin
        self.samplePeriod = samplePeriod
        self.end = end
    }
}

/// RAIM prediction parameters (`<RAIMParameters>`, RAIMParametersType in RAIM.xsd).
public struct RAIMParameters: Sendable, Equatable {
    /// Horizontal Alert Limit (RNP) value applied (`@rnpValue`, xs:double).
    public var rnpValue: Double?
    /// Integrity level applied (`@integrityLevel`, xs:string, e.g. "TERMINAL", "RNP-AR-0.1").
    public var integrityLevel: String?
    /// Minimum reported outage duration (`@minimumOutage`, xs:duration), kept as text.
    public var minimumOutage: String?
    /// Airport-specific mask angle override in degrees (`@maskAngle`, xs:double, airport only).
    public var maskAngle: Double?

    public init(rnpValue: Double? = nil,
                integrityLevel: String? = nil,
                minimumOutage: String? = nil,
                maskAngle: Double? = nil) {
        self.rnpValue = rnpValue
        self.integrityLevel = integrityLevel
        self.minimumOutage = minimumOutage
        self.maskAngle = maskAngle
    }
}

/// A single predicted RAIM outage (`<RAIMOutage>`, RAIMOutageType in RAIM.xsd).
public struct RAIMOutage: Sendable, Equatable {
    /// Outage start (`@beginOfOutage`, xs:dateTime), kept as text.
    public var beginOfOutage: String?
    /// Outage end (`@endOfOutage`, xs:dateTime), kept as text.
    public var endOfOutage: String?
    /// Worst horizontal protection limit during the outage (`@worstHPL`, xs:double).
    public var worstHPL: Double?
    /// Number of satellites used in the prediction (`@numberOfSatellites`, xs:int).
    public var numberOfSatellites: Int?

    public init(beginOfOutage: String? = nil,
                endOfOutage: String? = nil,
                worstHPL: Double? = nil,
                numberOfSatellites: Int? = nil) {
        self.beginOfOutage = beginOfOutage
        self.endOfOutage = endOfOutage
        self.worstHPL = worstHPL
        self.numberOfSatellites = numberOfSatellites
    }
}

/// A single predicted ADS-B outage (`<ADSBOutage>`, ADSBOutageType in RAIM.xsd).
public struct ADSBOutage: Sendable, Equatable {
    /// Outage start (`@beginOfOutage`, xs:dateTime), kept as text.
    public var beginOfOutage: String?
    /// Outage end (`@endOfOutage`, xs:dateTime), kept as text.
    public var endOfOutage: String?
    /// Number of satellites used in the prediction (`@numberOfSatellites`, xs:int).
    public var numberOfSatellites: Int?
    /// Worst Navigation Integrity Category (`@worstNic`, xs:int).
    public var worstNic: Int?
    /// Worst Navigation Accuracy Category for Position (`@worstNacp`, xs:int).
    public var worstNacp: Int?
    /// Worst Horizontal Figure of Merit (`@worstHfom`, xs:double).
    public var worstHfom: Double?

    public init(beginOfOutage: String? = nil,
                endOfOutage: String? = nil,
                numberOfSatellites: Int? = nil,
                worstNic: Int? = nil,
                worstNacp: Int? = nil,
                worstHfom: Double? = nil) {
        self.beginOfOutage = beginOfOutage
        self.endOfOutage = endOfOutage
        self.numberOfSatellites = numberOfSatellites
        self.worstNic = worstNic
        self.worstNacp = worstNacp
        self.worstHfom = worstHfom
    }
}

/// Information about one GNSS constellation used (`<SatelliteInformation>`,
/// SatelliteInformationType in RAIM.xsd).
public struct SatelliteInformation: Sendable, Equatable {
    /// GNSS constellation (`@GNSS`, xs:string, e.g. "GPS", "GALILEO", "GLONASS").
    public var gnss: String?
    /// Almanac identifier (`@almanac`, xs:string).
    public var almanac: String?
    /// List of active NANUs (`@nanus`, xs:string).
    public var nanus: String?

    public init(gnss: String? = nil, almanac: String? = nil, nanus: String? = nil) {
        self.gnss = gnss
        self.almanac = almanac
        self.nanus = nanus
    }
}

/// A spot RAIM prediction for one airport / integrity level
/// (`<RAIMAirportPrediction>`, RAIMAirportType in RAIM.xsd).
public struct RAIMAirportPrediction: Sendable, Equatable {
    /// Airport ICAO code (`<Airport>/<AirportICAOCode>`, AirportIdentificationType).
    public var airportICAO: String?
    /// Airport IATA code (`<Airport>/<AirportIATACode>`), if present.
    public var airportIATA: String?
    /// Human-readable airport name (`<Airport>/@airportName`).
    public var airportName: String?
    /// Airport elevation (`<Elevation>`, AltitudeType, minOccurs=0; samples use unit "ft").
    public var elevation: ARINCAltitude?
    /// Airport coordinates (`<Coordinates>`, minOccurs=0).
    public var coordinates: RAIMCoordinates?
    /// Prediction time-range parameters (`<TimeRangeParameters>`, minOccurs=0).
    public var timeRange: RAIMTimeRange?
    /// RAIM prediction parameters (`<RAIMParameters>`, minOccurs=0).
    public var parameters: RAIMParameters?
    /// Predicted RAIM outages (`<RAIMOutages>/<RAIMOutage>`, minOccurs=0).
    public var outages: [RAIMOutage]
    /// Satellite/GNSS information (`<SatelliteInformations>/<SatelliteInformation>`, minOccurs=0).
    public var satelliteInformation: [SatelliteInformation]
    /// Free-text remark (`<Remark>`, TextType, minOccurs=0).
    public var remark: String?
    /// True if an outage was predicted during the requested range (`@outageReported`, xs:boolean).
    public var outageReported: Bool?
    /// Airport function (`@airportFunction`, airportFunctionType, e.g. "DepartureAirport").
    public var airportFunction: String?

    public init(airportICAO: String? = nil,
                airportIATA: String? = nil,
                airportName: String? = nil,
                elevation: ARINCAltitude? = nil,
                coordinates: RAIMCoordinates? = nil,
                timeRange: RAIMTimeRange? = nil,
                parameters: RAIMParameters? = nil,
                outages: [RAIMOutage] = [],
                satelliteInformation: [SatelliteInformation] = [],
                remark: String? = nil,
                outageReported: Bool? = nil,
                airportFunction: String? = nil) {
        self.airportICAO = airportICAO
        self.airportIATA = airportIATA
        self.airportName = airportName
        self.elevation = elevation
        self.coordinates = coordinates
        self.timeRange = timeRange
        self.parameters = parameters
        self.outages = outages
        self.satelliteInformation = satelliteInformation
        self.remark = remark
        self.outageReported = outageReported
        self.airportFunction = airportFunction
    }
}

/// ADS-B prediction parameters for a trajectory (`<ADSBParameters>`, ADSBParametersType in RAIM.xsd).
public struct ADSBParameters: Sendable, Equatable {
    /// Minimum Navigation Integrity Category threshold (`@minNic`, xs:int).
    public var minNic: Int?
    /// Minimum Navigation Accuracy Category for Position threshold (`@minNacp`, xs:int).
    public var minNacp: Int?
    /// ADS-B prediction authority qualifier (`@integrityLevel`, xs:string).
    public var integrityLevel: String?
    /// Minimum outage span to report (`@minimumOutage`, xs:duration), kept as text.
    public var minimumOutage: String?

    public init(minNic: Int? = nil,
                minNacp: Int? = nil,
                integrityLevel: String? = nil,
                minimumOutage: String? = nil) {
        self.minNic = minNic
        self.minNacp = minNacp
        self.integrityLevel = integrityLevel
        self.minimumOutage = minimumOutage
    }
}

/// One waypoint along a predicted trajectory (`<Waypoint>` in RAIMTrajectoryType).
public struct RAIMWaypoint: Sendable, Equatable {
    /// FMC waypoint identifier (`@waypointId`, WaypointIdType, 1..5 chars).
    public var waypointId: String?
    /// ATC-FPL / artificial waypoint name (`@waypointName`), secondary to `waypointId`.
    public var waypointName: String?
    /// Country ICAO code (`@countryICAOCode`, CountryICAOCodeType).
    public var countryICAOCode: String?
    /// Waypoint long name (`@waypointLongName`).
    public var waypointLongName: String?
    /// Waypoint coordinates (`<Coordinates>`, minOccurs=0).
    public var coordinates: RAIMCoordinates?
    /// Airway from the previous waypoint, with type (`<Airway>`/`@type`, minOccurs=0).
    public var airway: String?
    /// Airway type (`<Airway>/@type`, e.g. "SID", "STAR", "RNAV", "Direct").
    public var airwayType: String?
    /// Time over the waypoint, UTC (`<TimeOverWaypoint>`, TimeBasicType, minOccurs=0), as text.
    public var timeOverWaypoint: String?
    /// Flight altitude from the previous waypoint (`<Altitude>`, AltitudeType, minOccurs=0).
    public var altitude: ARINCAltitude?
    /// RAIM parameters for the inbound segment (`<RAIMParameters>`, RAIMTrajectoryParametersType, minOccurs=0).
    public var parameters: RAIMParameters?
    /// Predicted RAIM outages on this waypoint/segment (`<RAIMOutages>`, minOccurs=0).
    public var raimOutages: [RAIMOutage]
    /// Predicted ADS-B outages on this waypoint/segment (`<ADSBOutages>`, minOccurs=0).
    public var adsbOutages: [ADSBOutage]

    public init(waypointId: String? = nil,
                waypointName: String? = nil,
                countryICAOCode: String? = nil,
                waypointLongName: String? = nil,
                coordinates: RAIMCoordinates? = nil,
                airway: String? = nil,
                airwayType: String? = nil,
                timeOverWaypoint: String? = nil,
                altitude: ARINCAltitude? = nil,
                parameters: RAIMParameters? = nil,
                raimOutages: [RAIMOutage] = [],
                adsbOutages: [ADSBOutage] = []) {
        self.waypointId = waypointId
        self.waypointName = waypointName
        self.countryICAOCode = countryICAOCode
        self.waypointLongName = waypointLongName
        self.coordinates = coordinates
        self.airway = airway
        self.airwayType = airwayType
        self.timeOverWaypoint = timeOverWaypoint
        self.altitude = altitude
        self.parameters = parameters
        self.raimOutages = raimOutages
        self.adsbOutages = adsbOutages
    }
}

/// One Estimated-Time-Over scenario for a trajectory (`<ETOScenario>` in RAIMTrajectoryType).
public struct RAIMETOScenario: Sendable, Equatable {
    /// Offset to the base ETO scenario (`@timeScenarioOffset`, xs:duration), kept as text.
    public var timeScenarioOffset: String?
    /// Waypoints in document order (`<Waypoint>`, maxOccurs=unbounded).
    public var waypoints: [RAIMWaypoint]

    public init(timeScenarioOffset: String? = nil, waypoints: [RAIMWaypoint] = []) {
        self.timeScenarioOffset = timeScenarioOffset
        self.waypoints = waypoints
    }
}

/// A RAIM prediction along a flight trajectory (`<RAIMTrajectoryPrediction>`,
/// RAIMTrajectoryType in RAIM.xsd).
public struct RAIMTrajectoryPrediction: Sendable, Equatable {
    /// ADS-B prediction parameters (`<ADSBParameters>`, minOccurs=0).
    public var adsbParameters: ADSBParameters?
    /// ETO scenarios (`<ETOScenarios>/<ETOScenario>`, minOccurs=0).
    public var etoScenarios: [RAIMETOScenario]
    /// Satellite/GNSS information (`<SatelliteInformations>/<SatelliteInformation>`, minOccurs=0).
    public var satelliteInformation: [SatelliteInformation]
    /// Free-text remark (`<Remark>`, TextType, minOccurs=0).
    public var remark: String?
    /// True if an outage was predicted during the requested range (`@outageReported`, xs:boolean).
    public var outageReported: Bool?
    /// Function of the airport the trajectory leads to (`@airportFunction`, airportFunctionType).
    public var airportFunction: String?

    public init(adsbParameters: ADSBParameters? = nil,
                etoScenarios: [RAIMETOScenario] = [],
                satelliteInformation: [SatelliteInformation] = [],
                remark: String? = nil,
                outageReported: Bool? = nil,
                airportFunction: String? = nil) {
        self.adsbParameters = adsbParameters
        self.etoScenarios = etoScenarios
        self.satelliteInformation = satelliteInformation
        self.remark = remark
        self.outageReported = outageReported
        self.airportFunction = airportFunction
    }
}
