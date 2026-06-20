// AirportDataMessage.swift
// ARINC633Kit
//
// Typed model for the CommonData AirportData message (root <AirportData>).
// Source: AirportData.xsd (CommonData/AirportData), group AirportDescription.grp in
// m633common.xsd, sample AirportData_1.xml.
//
// NOTE: The public type is named `AirportDataMessage` (not `AirportData`) to avoid a
// name collision with the existing FlightPlan `AirportData` model.
//
// Structure: <AirportData> carries the standard ARINC 633 envelope (M633Header +
// optional M633SupplementaryHeader) plus one or more repeated <Airport> descriptions.
// Each <Airport> has an identification (ICAO/IATA/name), a list of <Runway> entries,
// optional terminal procedures (SID/STAR), an airport reference point and elevation,
// and operational metadata (RFFS category, opening hours, UTC offset, ATIS freqs).

import Foundation

/// A parsed AirportData message: airport briefing descriptions for one or more airports.
///
/// Source: `AirportData.xsd` root `<AirportData>` (CommonData/AirportData). The payload
/// is a sequence of `<Airport>` descriptions (per `AirportDescription.grp`).
public struct AirportDataMessage: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Identifier of the operational flight plan (`@flightPlanId`, optional).
    public var flightPlanId: String?

    /// The date and time the briefing was created (`@creationTime`, required dateTime).
    public var creationTime: String?

    /// Whether this is a complete airport briefing package (`@fullPackage`, true) or an
    /// update to be merged with an existing briefing (false).
    public var fullPackage: Bool?

    /// One description per airport (`<Airport>`, repeated; per `AirportDescription.grp`).
    public var airports: [AirportDescription]

    /// Unrecognized child elements preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                flightPlanId: String? = nil,
                creationTime: String? = nil,
                fullPackage: Bool? = nil,
                airports: [AirportDescription] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.flightPlanId = flightPlanId
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.airports = airports
        self.extensions = extensions
    }
}

/// Briefing description for a single airport (`<Airport>`, per `AirportDescription.grp`).
public struct AirportDescription: Sendable, Equatable {
    /// Airport ICAO code (`AirportIdentification/AirportICAOCode`, 4-letter).
    public var airportICAO: String?
    /// Airport IATA code (`AirportIdentification/AirportIATACode`, 3-letter, optional).
    public var airportIATA: String?
    /// Human-readable airport name (`AirportIdentification/@airportName`, optional).
    public var airportName: String?

    /// Runways at this airport (`<Runway>`, repeated).
    public var runways: [AirportRunway]
    /// Terminal procedures such as SID/STAR (`<TerminalProcedures>`, repeated).
    public var terminalProcedures: [AirportTerminalProcedure]

    /// Magnetic variation at the airport reference point in degrees, east positive
    /// (`<MagneticVariation>`, optional).
    public var magneticVariation: Double?
    /// Airport elevation (`<Elevation>`, simple-content float with `@unit`, default "ft").
    public var elevation: ARINCAltitude?
    /// Airport reference point coordinates (`<AirportReferencePoint>/<Coordinates>`).
    public var referencePoint: ARINCCoordinate?

    /// Rescue and fire fighting category, 0..15 per ICAO (`<RescueAndFireFightingCategory>`).
    public var rescueAndFireFightingCategory: Int?
    /// Required flight crew qualification code, e.g. "A"/"B"/"C"
    /// (`<RequiredFlightCrewQualification>`, optional).
    public var requiredFlightCrewQualification: String?
    /// Opening hours, UTC start time (`<OpeningHours>/@from`, optional).
    public var openingHoursFrom: String?
    /// Opening hours, UTC end time (`<OpeningHours>/@until`, optional).
    public var openingHoursUntil: String?
    /// Local time offset to UTC as an ISO-8601 duration (`<LocalTimeOffsetToUTC>` text).
    public var localTimeOffsetToUTC: String?
    /// Whether `localTimeOffsetToUTC` is zero-or-positive (`<LocalTimeOffsetToUTC>/@positive`).
    public var localTimeOffsetPositive: Bool?
    /// ATIS radio frequencies in MHz (`<ATISRadioFrequencies>/<ATISFrequency>`, repeated).
    public var atisFrequencies: [Double]

    /// Display ordering hint (`@sequence`, optional in the legacy `<Airport>` form).
    public var sequence: String?

    /// Unrecognized child elements of this airport, preserved verbatim.
    public var extensions: [CapturedElement]

    public init(airportICAO: String? = nil,
                airportIATA: String? = nil,
                airportName: String? = nil,
                runways: [AirportRunway] = [],
                terminalProcedures: [AirportTerminalProcedure] = [],
                magneticVariation: Double? = nil,
                elevation: ARINCAltitude? = nil,
                referencePoint: ARINCCoordinate? = nil,
                rescueAndFireFightingCategory: Int? = nil,
                requiredFlightCrewQualification: String? = nil,
                openingHoursFrom: String? = nil,
                openingHoursUntil: String? = nil,
                localTimeOffsetToUTC: String? = nil,
                localTimeOffsetPositive: Bool? = nil,
                atisFrequencies: [Double] = [],
                sequence: String? = nil,
                extensions: [CapturedElement] = []) {
        self.airportICAO = airportICAO
        self.airportIATA = airportIATA
        self.airportName = airportName
        self.runways = runways
        self.terminalProcedures = terminalProcedures
        self.magneticVariation = magneticVariation
        self.elevation = elevation
        self.referencePoint = referencePoint
        self.rescueAndFireFightingCategory = rescueAndFireFightingCategory
        self.requiredFlightCrewQualification = requiredFlightCrewQualification
        self.openingHoursFrom = openingHoursFrom
        self.openingHoursUntil = openingHoursUntil
        self.localTimeOffsetToUTC = localTimeOffsetToUTC
        self.localTimeOffsetPositive = localTimeOffsetPositive
        self.atisFrequencies = atisFrequencies
        self.sequence = sequence
        self.extensions = extensions
    }
}

/// A runway within an airport description (`<Runway>`).
public struct AirportRunway: Sendable, Equatable {
    /// Runway designator (`@runwayIdentifier`, e.g. "33L"; required, 2..3 chars).
    public var runwayIdentifier: String
    /// Magnetic runway track in degrees (`<QFU>`, simple-content float, type "magnetic").
    public var qfuMagneticTrack: Double?
    /// Approach procedures applicable to this runway (`<Approach>`, repeated).
    public var approaches: [RunwayApproach]
    /// Landing distance available (`<LandingDistanceAvailable>`, `@unit` default "m").
    public var landingDistanceAvailable: ARINCDistance?
    /// Landing threshold coordinates (`<LandingThreshold>/<Coordinates>`).
    public var landingThreshold: ARINCCoordinate?
    /// Takeoff distance available (`<TakeoffDistanceAvailable>`, `@unit` default "m").
    public var takeoffDistanceAvailable: ARINCDistance?
    /// Takeoff run available (`<TakeoffRunAvailable>`, `@unit` default "m").
    public var takeoffRunAvailable: ARINCDistance?
    /// Runway elevation (`<Elevation>`, `@unit` default "ft").
    public var elevation: ARINCAltitude?
    /// Average runway slope in degrees, uphill positive (`<Slope>`, `@unit` default "deg").
    public var slope: Double?
    /// Whether the aircraft is approved to use this runway for regular operation
    /// (`<ApprovedForRegularOperation>`; false = emergency use only).
    public var approvedForRegularOperation: Bool?

    public init(runwayIdentifier: String,
                qfuMagneticTrack: Double? = nil,
                approaches: [RunwayApproach] = [],
                landingDistanceAvailable: ARINCDistance? = nil,
                landingThreshold: ARINCCoordinate? = nil,
                takeoffDistanceAvailable: ARINCDistance? = nil,
                takeoffRunAvailable: ARINCDistance? = nil,
                elevation: ARINCAltitude? = nil,
                slope: Double? = nil,
                approvedForRegularOperation: Bool? = nil) {
        self.runwayIdentifier = runwayIdentifier
        self.qfuMagneticTrack = qfuMagneticTrack
        self.approaches = approaches
        self.landingDistanceAvailable = landingDistanceAvailable
        self.landingThreshold = landingThreshold
        self.takeoffDistanceAvailable = takeoffDistanceAvailable
        self.takeoffRunAvailable = takeoffRunAvailable
        self.elevation = elevation
        self.slope = slope
        self.approvedForRegularOperation = approvedForRegularOperation
    }
}

/// An approach procedure applicable to a runway (`<Approach>`).
public struct RunwayApproach: Sendable, Equatable {
    /// Procedure name (`@procedureName`, e.g. "CISCO").
    public var procedureName: String?
    /// FMS procedure name (`@fMSProcedureName`).
    public var fmsProcedureName: String?
    /// Approach category code: "1","2","3","3a","3b","3c" (`@category`).
    public var category: String?
    /// Whether this is a precision approach (`@precisionApproach`, boolean).
    public var precisionApproach: Bool?
    /// Required horizontal visibility minimum (`<RequiredHorizontalVisibility>`,
    /// `@unit` default "m").
    public var requiredHorizontalVisibility: ARINCDistance?
    /// Required vertical visibility minimum (`<RequiredVerticalVisibility>`,
    /// `@unit` default "ft").
    public var requiredVerticalVisibility: ARINCDistance?

    public init(procedureName: String? = nil,
                fmsProcedureName: String? = nil,
                category: String? = nil,
                precisionApproach: Bool? = nil,
                requiredHorizontalVisibility: ARINCDistance? = nil,
                requiredVerticalVisibility: ARINCDistance? = nil) {
        self.procedureName = procedureName
        self.fmsProcedureName = fmsProcedureName
        self.category = category
        self.precisionApproach = precisionApproach
        self.requiredHorizontalVisibility = requiredHorizontalVisibility
        self.requiredVerticalVisibility = requiredVerticalVisibility
    }
}

/// A terminal procedure such as a SID or STAR (`<TerminalProcedures>`).
public struct AirportTerminalProcedure: Sendable, Equatable {
    /// Procedure name (`@procedureName`, e.g. "MYPROC").
    public var procedureName: String?
    /// FMS procedure name (`@fMSProcedureName`).
    public var fmsProcedureName: String?
    /// Procedure type (`@procedureType`, e.g. "SID" / "STAR").
    public var procedureType: String?
    /// Ordered waypoints of the procedure (`<Waypoint>`, repeated).
    public var waypoints: [ProcedureWaypoint]

    public init(procedureName: String? = nil,
                fmsProcedureName: String? = nil,
                procedureType: String? = nil,
                waypoints: [ProcedureWaypoint] = []) {
        self.procedureName = procedureName
        self.fmsProcedureName = fmsProcedureName
        self.procedureType = procedureType
        self.waypoints = waypoints
    }
}

/// A waypoint within a terminal procedure (`<Waypoint>`, per `waypointIdentification.grp`).
public struct ProcedureWaypoint: Sendable, Equatable {
    /// FMC waypoint identifier, 1..5 chars (`@waypointId`, optional).
    public var waypointId: String?
    /// Secondary waypoint name, e.g. "TOC"/"TOD" (`@waypointName`, optional).
    public var waypointName: String?
    /// Sequence ordinal within the procedure (`@sequenceId`, optional).
    public var sequenceId: Int?
    /// Waypoint coordinates (`<Coordinates>`, optional).
    public var coordinates: ARINCCoordinate?
    /// Airway leading from the previous waypoint (`<Airway>` text, optional).
    public var airway: String?
    /// Airway type, e.g. "airway"/"ATS"/"direct" (`<Airway>/@type`, optional).
    public var airwayType: String?

    public init(waypointId: String? = nil,
                waypointName: String? = nil,
                sequenceId: Int? = nil,
                coordinates: ARINCCoordinate? = nil,
                airway: String? = nil,
                airwayType: String? = nil) {
        self.waypointId = waypointId
        self.waypointName = waypointName
        self.sequenceId = sequenceId
        self.coordinates = coordinates
        self.airway = airway
        self.airwayType = airwayType
    }
}
