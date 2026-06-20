// RegionWeather.swift
// ARINC633Kit
//
// Typed model for the RegionWeatherBriefing (regional weather: SIGMET / AIRMET /
// AIREP / CONVECTIVE SIGMET / THUNDERSTORM WARNING) message.
// Source: RegionWeatherBriefing.xsd (root <RegionWeatherBriefing>), RegionWeather.xsd
// (the <RegionWeather> type), sample RegionWeather_1.xml.
//
// Structure: <RegionWeatherBriefing creationTime fullPackage> -> <RegionWeathers> ->
// one or more <RegionWeather>, each carrying the raw bulletin text, a <Location>
// (affected airspaces + a <Geography> polygon/spot with optional movement vector),
// applicability <Altitudes>, a <DecodedInformation> block (icing / turbulence /
// thunderstorm trend), and a free-text <Remark>. Note the message has two roots in the
// spec — <RegionWeatherBriefing> (the document) and the <RegionWeather> type — both
// resolve to this model.

import Foundation

/// A parsed RegionWeatherBriefing message: a package of regional weather bulletins.
///
/// Per `RegionWeatherBriefing.xsd`: `<RegionWeatherBriefing>` carries `creationTime`
/// and `fullPackage` attributes and wraps a `<RegionWeathers>` list of one or more
/// `<RegionWeather>` bulletins (SIGMETs, CONVECTIVE SIGMETs, AIRMETs, AIREPs).
public struct RegionWeatherBriefing: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Briefing creation time (`@creationTime`, xs:dateTime, required by schema).
    public let creationTime: String?

    /// Whether this is a complete briefing package versus an update to be merged with
    /// the existing briefing (`@fullPackage`, xs:boolean, required by schema).
    public let fullPackage: Bool

    /// The regional weather bulletins (`<RegionWeathers>/<RegionWeather>`,
    /// maxOccurs=unbounded).
    public var regions: [RegionWeather]

    /// Unrecognized top-level payload children preserved verbatim
    /// (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                creationTime: String? = nil,
                fullPackage: Bool = false,
                regions: [RegionWeather] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.regions = regions
        self.extensions = extensions
    }
}

/// A single regional weather bulletin (`<RegionWeather>`, RegionWeather.xsd
/// `RegionWeather` complexType).
public struct RegionWeather: Sendable, Equatable {
    // MARK: Attributes

    /// Weather information issuing office identifier (`@issuer`, key part 1, e.g. a
    /// 4-letter office code). minLength 0, maxLength 32.
    public var issuer: String?
    /// Weather provider / channel (`@source`, key part 2, e.g. "WSI", "DFS").
    public var source: String?
    /// Bulletin type (`@type`, regionWeatherType, key part 3, required): one of
    /// "AIREP", "SIGMET", "AIRMET", "CONVECTIVE SIGMET", "THUNDERSTORM WARNING".
    public var type: String?
    /// Start of the validity window (`@startValidTime`, xs:dateTime, optional).
    public var startValidTime: String?
    /// End of the validity window (`@endValidTime`, xs:dateTime, optional).
    public var endValidTime: String?
    /// Observation time of the weather information (`@observationTime`, xs:dateTime,
    /// key part 4, required).
    public var observationTime: String?
    /// Optional margin extending the start valid time (`@startApplicabilityTime`).
    public var startApplicabilityTime: String?
    /// Optional margin extending the end valid time (`@endApplicabilityTime`).
    public var endApplicabilityTime: String?
    /// Presentation priority, 1 = highest, 3 = default (`@priority`, range 1...5).
    public var priority: Int?
    /// Presentation ordering hint (`@sequence`, xs:nonNegativeInteger).
    public var sequence: Int?

    // MARK: Elements

    /// Raw, human-readable bulletin text (`<RegionWeatherText>`, TextType; paragraphs
    /// joined by newlines). minOccurs=0.
    public var text: String?

    /// Location the bulletin applies to (`<Location>`, minOccurs=0): affected
    /// airspaces and/or a geographic area.
    public var location: RegionWeatherLocation?

    /// Applicability altitude(s) (`<Altitudes>`, AltitudeInfoType, minOccurs=0).
    /// Either a list of individual `<Altitude>` values or an upper/lower band.
    public var altitudes: RegionWeatherAltitudes?

    /// Decoded phenomenon information (`<DecodedInformation>`, minOccurs=0).
    public var decoded: RegionWeatherDecodedInformation?

    /// Free-text remark provided by ground staff (`<Remark>`, TextType, minOccurs=0).
    public var remark: String?

    /// Unrecognized child elements preserved verbatim (`<xs:any namespace="##other">`
    /// plus any unmapped children).
    public var extensions: [CapturedElement]

    public init(issuer: String? = nil,
                source: String? = nil,
                type: String? = nil,
                startValidTime: String? = nil,
                endValidTime: String? = nil,
                observationTime: String? = nil,
                startApplicabilityTime: String? = nil,
                endApplicabilityTime: String? = nil,
                priority: Int? = nil,
                sequence: Int? = nil,
                text: String? = nil,
                location: RegionWeatherLocation? = nil,
                altitudes: RegionWeatherAltitudes? = nil,
                decoded: RegionWeatherDecodedInformation? = nil,
                remark: String? = nil,
                extensions: [CapturedElement] = []) {
        self.issuer = issuer
        self.source = source
        self.type = type
        self.startValidTime = startValidTime
        self.endValidTime = endValidTime
        self.observationTime = observationTime
        self.startApplicabilityTime = startApplicabilityTime
        self.endApplicabilityTime = endApplicabilityTime
        self.priority = priority
        self.sequence = sequence
        self.text = text
        self.location = location
        self.altitudes = altitudes
        self.decoded = decoded
        self.remark = remark
        self.extensions = extensions
    }
}

/// Where a regional weather bulletin applies (`<Location>` in RegionWeather.xsd).
public struct RegionWeatherLocation: Sendable, Equatable {
    /// Affected airspaces, used to identify and group bulletins
    /// (`<Airspaces>/<Airspace>`, maxOccurs=unbounded).
    public var airspaces: [RegionWeatherAirspace]
    /// The geographic area the bulletin applies to (`<Geography>`, GeographyType,
    /// minOccurs=0).
    public var geography: RegionWeatherGeography?

    public init(airspaces: [RegionWeatherAirspace] = [],
                geography: RegionWeatherGeography? = nil) {
        self.airspaces = airspaces
        self.geography = geography
    }
}

/// An affected airspace (`<Airspace>`).
public struct RegionWeatherAirspace: Sendable, Equatable {
    /// 4-letter airspace ICAO code (`@airspaceICAOCode`, e.g. "LOVV").
    public var icaoCode: String?
    /// Long airspace name (`<AirspaceName>`, minOccurs=0).
    public var name: String?

    public init(icaoCode: String? = nil, name: String? = nil) {
        self.icaoCode = icaoCode
        self.name = name
    }
}

/// A geographic area (`<Geography>`, GeographyType). The type offers a choice of a
/// `<Polygon>` (used by the SIGMET samples) or a `<Spot>`, plus an optional movement
/// vector (`<MovementSpeed>` / `<MovementDirection>`).
public struct RegionWeatherGeography: Sendable, Equatable {
    /// A bounding polygon of coordinates (`<Polygon>`), if present.
    public var polygon: RegionWeatherPolygon?
    /// A single point with optional radius (`<Spot>`), if present.
    public var spot: RegionWeatherSpot?
    /// Velocity the area moves with (`<MovementSpeed>`, SpeedType; default unit kt).
    public var movementSpeed: ARINCSpeed?
    /// Direction the area moves in (`<MovementDirection>`, DirectionType; default unit
    /// deg).
    public var movementDirection: ARINCDirection?
    /// Unmapped geography children preserved verbatim.
    public var extensions: [CapturedElement]

    public init(polygon: RegionWeatherPolygon? = nil,
                spot: RegionWeatherSpot? = nil,
                movementSpeed: ARINCSpeed? = nil,
                movementDirection: ARINCDirection? = nil,
                extensions: [CapturedElement] = []) {
        self.polygon = polygon
        self.spot = spot
        self.movementSpeed = movementSpeed
        self.movementDirection = movementDirection
        self.extensions = extensions
    }
}

/// A bounding polygon (`<Polygon>` inside GeographyType): an ordered ring of
/// coordinates with an optional expansion margin.
public struct RegionWeatherPolygon: Sendable, Equatable {
    /// Vertices in document order (`<Coordinates>`, maxOccurs=unbounded).
    public var coordinates: [RegionWeatherCoordinate]
    /// Additional margin the polygon is expanded by (`<BorderMargin>`, DistanceType,
    /// minOccurs=0; default unit NM).
    public var borderMargin: ARINCDistance?

    public init(coordinates: [RegionWeatherCoordinate] = [],
                borderMargin: ARINCDistance? = nil) {
        self.coordinates = coordinates
        self.borderMargin = borderMargin
    }
}

/// A single point location (`<Spot>` inside GeographyType).
public struct RegionWeatherSpot: Sendable, Equatable {
    /// Decoded coordinate (arc-seconds in XML, converted to decimal degrees); `nil` if
    /// the latitude/longitude could not be parsed as numbers.
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

/// A single polygon vertex (`<Coordinates>` inside `<Polygon>`).
public struct RegionWeatherCoordinate: Sendable, Equatable {
    /// Vertex ordering hint (`@sequence`, xs:nonNegativeInteger).
    public var sequence: Int?
    /// Decoded coordinate (arc-seconds in XML, converted to decimal degrees); `nil` if
    /// the latitude/longitude could not be parsed as numbers.
    public var coordinate: ARINCCoordinate?
    /// Raw latitude attribute in arc-seconds, retained for fidelity (`@latitude`).
    public var latitudeArcSeconds: String?
    /// Raw longitude attribute in arc-seconds, retained for fidelity (`@longitude`).
    public var longitudeArcSeconds: String?

    public init(sequence: Int? = nil,
                coordinate: ARINCCoordinate? = nil,
                latitudeArcSeconds: String? = nil,
                longitudeArcSeconds: String? = nil) {
        self.sequence = sequence
        self.coordinate = coordinate
        self.latitudeArcSeconds = latitudeArcSeconds
        self.longitudeArcSeconds = longitudeArcSeconds
    }
}

/// Applicability altitude information (`<Altitudes>`, AltitudeInfoType).
/// The schema offers a choice: a list of individual altitudes, or an upper/lower
/// band. Both are surfaced here; only one is populated for a valid document.
public struct RegionWeatherAltitudes: Sendable, Equatable {
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

/// Decoded weather phenomenon information for a bulletin (`<DecodedInformation>`). All
/// members are optional.
public struct RegionWeatherDecodedInformation: Sendable, Equatable {
    /// Decoded icing phenomenon (`<Icing>`).
    public var icing: RegionWeatherIcing?
    /// Decoded turbulence phenomenon (`<Turbulence>`, TurbulenceType).
    public var turbulence: RegionWeatherTurbulence?
    /// Thunderstorm trend (`<Thunderstorm>/<Trend>`, thunderstormTrendType: one of
    /// "developing", "developed", "diminishing").
    public var thunderstormTrend: String?

    public init(icing: RegionWeatherIcing? = nil,
                turbulence: RegionWeatherTurbulence? = nil,
                thunderstormTrend: String? = nil) {
        self.icing = icing
        self.turbulence = turbulence
        self.thunderstormTrend = thunderstormTrend
    }
}

/// Decoded icing information (`<Icing>`).
public struct RegionWeatherIcing: Sendable, Equatable {
    /// Icing intensity (`@intensity`, intensityType, required).
    public var intensity: String?
    /// Type of ice, e.g. clear ice / rime ice (`@icingType`, required).
    public var icingType: String?

    public init(intensity: String? = nil, icingType: String? = nil) {
        self.intensity = intensity
        self.icingType = icingType
    }
}

/// Decoded turbulence information (`<Turbulence>`, TurbulenceType).
public struct RegionWeatherTurbulence: Sendable, Equatable {
    /// Type of turbulence, e.g. sky clear / wake (`@turbulenceType`, default "false").
    public var turbulenceType: String?
    /// Eddy dissipation rate (`@edr`, range 0.0...1.0).
    public var edr: Double?
    /// Turbulence intensity (`@intensity`, intensityType).
    public var intensity: String?

    public init(turbulenceType: String? = nil,
                edr: Double? = nil,
                intensity: String? = nil) {
        self.turbulenceType = turbulenceType
        self.edr = edr
        self.intensity = intensity
    }
}
