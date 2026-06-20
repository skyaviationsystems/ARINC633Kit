// PIREP.swift
// ARINC633Kit
//
// Typed model for the PIREPBriefing (Pilot Report briefing) message.
// Source: PIREPBriefing.xsd (root <PIREPBriefing>), PIREP.xsd (the <PIREP> type),
// samples PirepBriefing_1..2.xml.
//
// Structure: <PIREPBriefing creationTime fullPackage> -> <PIREPs> -> one or more
// <PIREP>, each carrying the raw report text, a <Location> (airspaces / geography /
// airport), applicability <Altitudes>, and a <DecodedInformation> block describing
// the observed phenomenon (icing, turbulence, thunderstorm, wind shear, etc.).

import Foundation

/// A parsed PIREPBriefing message: a collection of pilot reports.
///
/// Per `PIREPBriefing.xsd`: `<PIREPBriefing>` carries `creationTime` and
/// `fullPackage` attributes and wraps a `<PIREPs>` list of one or more `<PIREP>`.
public struct PIREPBriefing: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Briefing creation time (`@creationTime`, xs:dateTime, required by schema).
    public let creationTime: String?

    /// Whether this is a complete briefing package versus an update to be merged
    /// (`@fullPackage`, xs:boolean, required by schema).
    public let fullPackage: Bool

    /// The pilot reports (`<PIREPs>/<PIREP>`, maxOccurs=unbounded).
    public var pireps: [PIREP]

    /// Raw payload text retained for backward compatibility with the former stub.
    /// Always `nil` from the full parser; kept so existing callers still compile.
    public let rawContent: String?

    /// Unrecognized top-level payload children preserved verbatim
    /// (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                creationTime: String? = nil,
                fullPackage: Bool = false,
                pireps: [PIREP] = [],
                rawContent: String? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.pireps = pireps
        self.rawContent = rawContent
        self.extensions = extensions
    }
}

/// A single pilot report (`<PIREP>`, PIREP.xsd `PIREP` complexType).
public struct PIREP: Sendable, Equatable {
    // MARK: Attributes

    /// Weather information issuing office identifier (`@issuer`, key part 1).
    public var issuer: String?
    /// Weather provider / channel (`@source`, key part 2).
    public var source: String?
    /// Observation time of the report (`@observationTime`, xs:dateTime, required).
    public var observationTime: String?
    /// Start of the validity window (`@startValidTime`, xs:dateTime, optional).
    public var startValidTime: String?
    /// End of the validity window (`@endValidTime`, xs:dateTime, optional).
    public var endValidTime: String?
    /// Optional extension of the start valid time (`@startApplicabilityTime`).
    public var startApplicabilityTime: String?
    /// Optional extension of the end valid time (`@endApplicabilityTime`).
    public var endApplicabilityTime: String?
    /// Presentation priority, 1 = highest, 3 = default (`@priority`, range 1...5).
    public var priority: Int?
    /// Presentation ordering hint (`@sequence`, xs:nonNegativeInteger).
    public var sequence: Int?

    // MARK: Elements

    /// Raw, human-readable report text (`<PirepText>`, TextType; paragraphs joined
    /// by newlines). minOccurs=0.
    public var pirepText: String?

    /// Location the report applies to (`<Location>`, required element). The schema
    /// permits any combination of airspaces, geography, and airport, all optional.
    public var location: PIREPLocation

    /// Applicability altitude(s) (`<Altitudes>`, AltitudeInfoType, minOccurs=0).
    /// Either a list of individual `<Altitude>` values or an upper/lower band.
    public var altitudes: PIREPAltitudes?

    /// Decoded phenomenon information (`<DecodedInformation>`, minOccurs=0).
    public var decoded: PIREPDecodedInformation?

    /// Free-text remark attached to the report (`<Remark>`, TextType, minOccurs=0).
    public var remark: String?

    /// Aircraft ICAO type designator (`<AircraftICAOType>`, 4 chars, minOccurs=0).
    public var aircraftICAOType: String?

    /// Unrecognized child elements preserved verbatim (`<xs:any namespace="##other">`
    /// plus any unmapped children).
    public var extensions: [CapturedElement]

    public init(issuer: String? = nil,
                source: String? = nil,
                observationTime: String? = nil,
                startValidTime: String? = nil,
                endValidTime: String? = nil,
                startApplicabilityTime: String? = nil,
                endApplicabilityTime: String? = nil,
                priority: Int? = nil,
                sequence: Int? = nil,
                pirepText: String? = nil,
                location: PIREPLocation = PIREPLocation(),
                altitudes: PIREPAltitudes? = nil,
                decoded: PIREPDecodedInformation? = nil,
                remark: String? = nil,
                aircraftICAOType: String? = nil,
                extensions: [CapturedElement] = []) {
        self.issuer = issuer
        self.source = source
        self.observationTime = observationTime
        self.startValidTime = startValidTime
        self.endValidTime = endValidTime
        self.startApplicabilityTime = startApplicabilityTime
        self.endApplicabilityTime = endApplicabilityTime
        self.priority = priority
        self.sequence = sequence
        self.pirepText = pirepText
        self.location = location
        self.altitudes = altitudes
        self.decoded = decoded
        self.remark = remark
        self.aircraftICAOType = aircraftICAOType
        self.extensions = extensions
    }
}

/// Where a pilot report applies (`<Location>` in PIREP.xsd).
public struct PIREPLocation: Sendable, Equatable {
    /// Affected airspaces used to group reports (`<Airspaces>/<Airspace>`).
    public var airspaces: [PIREPAirspace]
    /// A point or area the report applies to (`<Geography>`, GeographyType).
    public var geography: PIREPGeography?
    /// Involved airport, with optional runways (`<Airport>`).
    public var airport: PIREPAirport?

    public init(airspaces: [PIREPAirspace] = [],
                geography: PIREPGeography? = nil,
                airport: PIREPAirport? = nil) {
        self.airspaces = airspaces
        self.geography = geography
        self.airport = airport
    }
}

/// An affected airspace (`<Airspace>`).
public struct PIREPAirspace: Sendable, Equatable {
    /// 4-letter airspace ICAO code (`@airspaceICAOCode`).
    public var icaoCode: String?
    /// Long airspace name (`<AirspaceName>`, minOccurs=0).
    public var name: String?

    public init(icaoCode: String? = nil, name: String? = nil) {
        self.icaoCode = icaoCode
        self.name = name
    }
}

/// A geographic location (`<Geography>`, GeographyType). PIREP samples use the
/// `<Spot>` variant; the `<Polygon>` variant is preserved via `extensions`.
public struct PIREPGeography: Sendable, Equatable {
    /// A single point with an optional applicability radius (`<Spot>`).
    public var spot: PIREPSpot?
    /// Unmapped geography children (e.g. `<Polygon>`), preserved verbatim.
    public var extensions: [CapturedElement]

    public init(spot: PIREPSpot? = nil, extensions: [CapturedElement] = []) {
        self.spot = spot
        self.extensions = extensions
    }
}

/// A point location with optional radius (`<Spot>`).
public struct PIREPSpot: Sendable, Equatable {
    /// Decoded coordinate (arc-seconds in XML, converted to decimal degrees).
    /// `nil` if latitude/longitude could not be parsed as numbers.
    public var coordinate: ARINCCoordinate?
    /// Raw latitude attribute in arc-seconds, retained for fidelity (`@latitude`).
    public var latitudeArcSeconds: String?
    /// Raw longitude attribute in arc-seconds, retained for fidelity (`@longitude`).
    public var longitudeArcSeconds: String?
    /// Applicability radius (`<Radius>`, DistanceType, minOccurs=0; default unit NM).
    public var radius: ARINCDistance?

    public init(coordinate: ARINCCoordinate? = nil,
                latitudeArcSeconds: String? = nil,
                longitudeArcSeconds: String? = nil,
                radius: ARINCDistance? = nil) {
        self.coordinate = coordinate
        self.latitudeArcSeconds = latitudeArcSeconds
        self.longitudeArcSeconds = longitudeArcSeconds
        self.radius = radius
    }
}

/// An airport reference inside a report location (`<Airport>`,
/// AirportIdentificationType with optional `<Runways>`).
public struct PIREPAirport: Sendable, Equatable {
    /// 4-letter airport ICAO code (`<AirportICAOCode>`).
    public var icaoCode: String?
    /// 3-letter airport IATA code (`<AirportIATACode>`).
    public var iataCode: String?
    /// Runway designators referenced by the report (`<Runways>/<Runway>`).
    public var runways: [String]

    public init(icaoCode: String? = nil, iataCode: String? = nil, runways: [String] = []) {
        self.icaoCode = icaoCode
        self.iataCode = iataCode
        self.runways = runways
    }
}

/// Applicability altitude information (`<Altitudes>`, AltitudeInfoType).
/// The schema offers a choice: a list of individual altitudes, or an upper/lower
/// band. Both are surfaced here; only one is populated for a valid document.
public struct PIREPAltitudes: Sendable, Equatable {
    /// Individual applicability altitudes (`<Altitude>`, maxOccurs=unbounded).
    public var altitudes: [ARINCAltitude]
    /// Upper bound of the applicability band (`<Upper>`).
    public var upper: ARINCAltitude?
    /// Lower bound of the applicability band (`<Lower>`).
    public var lower: ARINCAltitude?

    public init(altitudes: [ARINCAltitude] = [],
                upper: ARINCAltitude? = nil,
                lower: ARINCAltitude? = nil) {
        self.altitudes = altitudes
        self.upper = upper
        self.lower = lower
    }
}

/// Decoded phenomenon information for a report (`<DecodedInformation>`). All members
/// are optional; a report typically populates exactly one phenomenon.
public struct PIREPDecodedInformation: Sendable, Equatable {
    /// Icing phenomenon (`<Icing>`).
    public var icing: PIREPIcing?
    /// Turbulence phenomenon (`<Turbulence>`).
    public var turbulence: PIREPTurbulence?
    /// Thunderstorm trend (`<Thunderstorm>/<Trend>`).
    public var thunderstormTrend: String?
    /// Temperature measured at the report position (`<SpotTemperature>`).
    public var spotTemperature: ARINCTemperature?
    /// Wind measured at the report position (`<SpotWind>`, WindType).
    public var spotWind: PIREPWind?
    /// Wind-shear intensity (`<WindShear>/@intensity`).
    public var windShearIntensity: String?
    /// Microburst indicator (`<Microburst>`, xs:boolean).
    public var microburst: Bool?
    /// Braking action report (`<BrakingAction>`, brakingActionType).
    public var brakingAction: String?

    public init(icing: PIREPIcing? = nil,
                turbulence: PIREPTurbulence? = nil,
                thunderstormTrend: String? = nil,
                spotTemperature: ARINCTemperature? = nil,
                spotWind: PIREPWind? = nil,
                windShearIntensity: String? = nil,
                microburst: Bool? = nil,
                brakingAction: String? = nil) {
        self.icing = icing
        self.turbulence = turbulence
        self.thunderstormTrend = thunderstormTrend
        self.spotTemperature = spotTemperature
        self.spotWind = spotWind
        self.windShearIntensity = windShearIntensity
        self.microburst = microburst
        self.brakingAction = brakingAction
    }
}

/// Decoded icing information (`<Icing>`).
public struct PIREPIcing: Sendable, Equatable {
    /// Type of ice, e.g. clear ice / rime ice (`@icingType`, required).
    public var icingType: String?
    /// Icing intensity (`@intensity`, intensityType, required).
    public var intensity: String?
    /// Indicated airspeed at the report position (`<IndicatedAirSpeed>`, SpeedType).
    public var indicatedAirSpeed: ARINCSpeed?
    /// Static air temperature (`<Temperatures>/<StaticAirTemperature>`, required).
    public var staticAirTemperature: ARINCTemperature?
    /// Total air temperature (`<Temperatures>/<TotalAirTemperature>`, minOccurs=0).
    public var totalAirTemperature: ARINCTemperature?

    public init(icingType: String? = nil,
                intensity: String? = nil,
                indicatedAirSpeed: ARINCSpeed? = nil,
                staticAirTemperature: ARINCTemperature? = nil,
                totalAirTemperature: ARINCTemperature? = nil) {
        self.icingType = icingType
        self.intensity = intensity
        self.indicatedAirSpeed = indicatedAirSpeed
        self.staticAirTemperature = staticAirTemperature
        self.totalAirTemperature = totalAirTemperature
    }
}

/// Decoded turbulence information (`<Turbulence>`).
public struct PIREPTurbulence: Sendable, Equatable {
    /// Type of turbulence, e.g. sky clear / wake (`@turbulenceType`, default "false").
    public var turbulenceType: String?
    /// Turbulence intensity (`@intensity`, intensityType, required).
    public var intensity: String?
    /// Whether the turbulence occurred in or near cloud (`@inOrNearClounds`,
    /// xs:boolean — attribute name spelled as in the schema).
    public var inOrNearClouds: Bool?
    /// Duration of the turbulence (`<Duration>`, xs:duration, minOccurs=0).
    public var duration: String?

    public init(turbulenceType: String? = nil,
                intensity: String? = nil,
                inOrNearClouds: Bool? = nil,
                duration: String? = nil) {
        self.turbulenceType = turbulenceType
        self.intensity = intensity
        self.inOrNearClouds = inOrNearClouds
        self.duration = duration
    }
}

/// Decoded wind reading (`<SpotWind>`, WindType: direction + speed).
public struct PIREPWind: Sendable, Equatable {
    /// Wind direction (`<Direction>`, DirectionType; default unit degrees).
    public var direction: ARINCDirection?
    /// Wind speed (`<Speed>`, SpeedType; default unit kt).
    public var speed: ARINCSpeed?

    public init(direction: ARINCDirection? = nil, speed: ARINCSpeed? = nil) {
        self.direction = direction
        self.speed = speed
    }
}
