// UpperAirData.swift
// ARINC633Kit
//
// Typed model for the UpperAirData message (upper-air "Meteo Synopsis").
// Source: UpperAirData.xsd (root <UpperAirData>), sample UpperAirData_1.xml.
//
// Structure: <UpperAirData> carries an optional <ObservationTimes> list (prognosis
// reference times) followed by up to three flight-phase sections — <ClimbPhase>,
// <CruisePhase>, <DescentPhase>. Climb/Descent phases hold a flat list of
// per-altitude predicted-information entries; Cruise holds <Waypoints>/<Waypoint>,
// each with optional coordinates, its own per-altitude entries and an optional
// tropopause altitude.
//
// SAFETY: wind and temperature aloft drive fuel-burn and performance computations.
// Every measurement here preserves its source unit (see the unit fields on
// ARINCAltitude/ARINCSpeed/ARINCTemperature/ARINCDirection) — never assume a unit;
// read it from the value. Altitudes default to "ft/100", wind speed to "kt",
// direction to "deg", temperature to "C", matching the m633common unit enumerations.

import Foundation

/// A parsed UpperAirData message: predicted upper-air wind and temperature data
/// (a "Meteo Synopsis") organized by flight phase. Root element `<UpperAirData>`.
public struct UpperAirData: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Supplementary header (`<M633SupplementaryHeader>`).
    public let supplementaryHeader: SupplementaryHeader

    /// Identifier of the operational flight plan this UAD belongs to
    /// (`@flightPlanId`, required by the schema).
    public var flightPlanId: String?

    /// Time when the upper-air data was established (`@prognosisTime`, ISO 8601).
    public var prognosisTime: String?

    /// Prognosis reference times used to compute the flight plan
    /// (`<ObservationTimes>/<ObservationTime>`).
    public var observationTimes: [UpperAirObservationTime]

    /// UAD entries for the climb phase (`<ClimbPhase>`), one per modeled altitude.
    public var climbPhase: [UpperAirAltitudeEntry]

    /// UAD waypoints for the cruise phase (`<CruisePhase>/<Waypoints>/<Waypoint>`).
    public var cruiseWaypoints: [UpperAirWaypoint]

    /// UAD entries for the descent phase (`<DescentPhase>`), one per modeled altitude.
    public var descentPhase: [UpperAirAltitudeEntry]

    /// Unrecognized child elements preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                flightPlanId: String? = nil,
                prognosisTime: String? = nil,
                observationTimes: [UpperAirObservationTime] = [],
                climbPhase: [UpperAirAltitudeEntry] = [],
                cruiseWaypoints: [UpperAirWaypoint] = [],
                descentPhase: [UpperAirAltitudeEntry] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.flightPlanId = flightPlanId
        self.prognosisTime = prognosisTime
        self.observationTimes = observationTimes
        self.climbPhase = climbPhase
        self.cruiseWaypoints = cruiseWaypoints
        self.descentPhase = descentPhase
        self.extensions = extensions
    }
}

/// A prognosis reference time (`<ObservationTime>`): the element text is the time the
/// prognosis was established; `@prognosisValidityTime` is the time it is valid for.
public struct UpperAirObservationTime: Sendable, Equatable {
    /// Time the prognosis was established (element text, ISO 8601).
    public var establishedTime: String?
    /// Time for which the prognosis is valid (`@prognosisValidityTime`, ISO 8601).
    public var validityTime: String?

    public init(establishedTime: String? = nil, validityTime: String? = nil) {
        self.establishedTime = establishedTime
        self.validityTime = validityTime
    }
}

/// A cruise-phase waypoint carrying upper-air data (`<Waypoint>`).
public struct UpperAirWaypoint: Sendable, Equatable {
    /// 1..5 char FMC waypoint code (`@waypointId`), if present.
    public var waypointId: String?
    /// Secondary / artificial waypoint name such as "TOC"/"TOD" (`@waypointName`).
    public var waypointName: String?
    /// Display/ordering sequence id (`@sequenceId`).
    public var sequenceId: Int?

    /// Geographic position (`<Coordinates>`), converted from arc-seconds. SAFETY:
    /// latitude/longitude are stored as decimal degrees via `ARINCCoordinate`.
    public var coordinates: ARINCCoordinate?

    /// Per-altitude predicted upper-air entries for this waypoint.
    public var entries: [UpperAirAltitudeEntry]

    /// Tropopause altitude at this waypoint (`<Tropopause>`, an AltitudeType),
    /// if provided. Unit preserved on the value.
    public var tropopause: ARINCAltitude?

    public init(waypointId: String? = nil,
                waypointName: String? = nil,
                sequenceId: Int? = nil,
                coordinates: ARINCCoordinate? = nil,
                entries: [UpperAirAltitudeEntry] = [],
                tropopause: ARINCAltitude? = nil) {
        self.waypointId = waypointId
        self.waypointName = waypointName
        self.sequenceId = sequenceId
        self.coordinates = coordinates
        self.entries = entries
        self.tropopause = tropopause
    }
}

/// Predicted upper-air information at a single altitude
/// (`<AltitudeSpecificPredictedInformation>`).
///
/// SAFETY: wind/temperature aloft inform fuel and performance planning. Always
/// inspect each measurement's `unit` before computing — values are stored as-read.
public struct UpperAirAltitudeEntry: Sendable, Equatable {
    /// The altitude this entry applies to (`<Altitude>`, AltitudeType, default
    /// unit "ft/100" i.e. flight-level hundreds of feet).
    public var altitude: ARINCAltitude?

    /// Time this altitude/waypoint is planned to be passed (`@predictedTime`, ISO 8601).
    public var predictedTime: String?

    /// Whether this entry's flight level is the one planned in the OFP
    /// (`@plannedFlightLevel`). Only one entry per waypoint should be flagged.
    public var plannedFlightLevel: String?

    /// Horizontal wind direction (`<WindData>/<HorizontalWind>/<Direction>`,
    /// default unit "deg"). The `<Value @type>` (true/magnetic) is not modeled here.
    public var windDirection: ARINCDirection?

    /// Horizontal wind speed (`<WindData>/<HorizontalWind>/<Speed>`, default "kt").
    public var windSpeed: ARINCSpeed?

    /// Vertical wind component (`<WindData>/<VerticalWind>`, a SpeedType), if present.
    public var verticalWind: ARINCSpeed?

    /// Wind component along the planned track (`<WindComponent>`, a SpeedType).
    /// SAFETY: sign convention is per the flight-planning policy; preserve the unit.
    public var windComponent: ARINCSpeed?

    /// Static air temperature (`<TemperatureData>/<Temperature>`, default "C").
    public var temperature: ARINCTemperature?

    /// ISA deviation (`<TemperatureData>/<ISADeviation>`, a TemperatureType).
    public var isaDeviation: ARINCTemperature?

    /// Total Air Temperature / TAT (`<TemperatureData>/<TotalAirTemperature>`).
    public var totalAirTemperature: ARINCTemperature?

    public init(altitude: ARINCAltitude? = nil,
                predictedTime: String? = nil,
                plannedFlightLevel: String? = nil,
                windDirection: ARINCDirection? = nil,
                windSpeed: ARINCSpeed? = nil,
                verticalWind: ARINCSpeed? = nil,
                windComponent: ARINCSpeed? = nil,
                temperature: ARINCTemperature? = nil,
                isaDeviation: ARINCTemperature? = nil,
                totalAirTemperature: ARINCTemperature? = nil) {
        self.altitude = altitude
        self.predictedTime = predictedTime
        self.plannedFlightLevel = plannedFlightLevel
        self.windDirection = windDirection
        self.windSpeed = windSpeed
        self.verticalWind = verticalWind
        self.windComponent = windComponent
        self.temperature = temperature
        self.isaDeviation = isaDeviation
        self.totalAirTemperature = totalAirTemperature
    }
}
