// Hazards.swift
// ARINC633Kit
//
// Typed model for the HazardBriefing message.
// Source: HazardBriefing.xsd (root <HazardBriefing>), HazardAdvisory.xsd
// (the HazardAdvisory complex type), sample HazardBriefing_1.xml.
//
// Structure: <HazardBriefing> -> <HazardAdvisories> -> one <HazardAdvisory> per
// advisory. Each advisory carries a hazard type/phenomenon, affected airspaces, an
// optional hazardous area (e.g. a volcano with coordinates and elevation), free-text
// hazard details, an observed extent and a list of forecast extents (both with
// optional altitude bands and a geographic shape), plus remark and raw-message text.
// Geometry-heavy subtrees (Coordinates / Polygon / Spot / Geography) are preserved as
// captured elements rather than fully decoded, since they carry no measurement units.

import Foundation

/// A parsed HazardBriefing message: a package of hazard advisories (volcanic ash,
/// radioactive cloud, pollution, etc.) for a flight or region.
///
/// Provenance: `HazardBriefing.xsd`, root `<HazardBriefing>`.
public struct HazardBriefing: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Date/time the briefing was created (`@creationTime`, required in the schema).
    public var creationTime: String?

    /// Whether this is a complete briefing package (`@fullPackage`, required): `true`
    /// for a full package, `false` when the content is an update to be merged.
    public var fullPackage: Bool?

    /// The advisories carried by this briefing (`<HazardAdvisories>/<HazardAdvisory>`).
    public var advisories: [HazardAdvisory]

    /// Unrecognized top-level payload children preserved verbatim (vendor extensions).
    public var extensions: [CapturedElement]

    /// Backward-compatible initializer. New parameters are defaulted so existing
    /// call sites of `HazardBriefing(header:supplementaryHeader:)` keep compiling.
    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                creationTime: String? = nil,
                fullPackage: Bool? = nil,
                advisories: [HazardAdvisory] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.creationTime = creationTime
        self.fullPackage = fullPackage
        self.advisories = advisories
        self.extensions = extensions
    }
}

/// A single hazard advisory (`<HazardAdvisory>`, type `HazardAdvisory` in
/// HazardAdvisory.xsd). All elements and attributes other than `HazardType` are
/// optional per the schema (minOccurs=0 / `use` unspecified).
public struct HazardAdvisory: Sendable, Equatable {
    /// Kind of hazard described (`<HazardType>`, required): e.g. volcanic ash,
    /// pollution, nuclear/radioactive cloud.
    public var hazardType: String?

    /// Affected airspaces (`<Airspaces>/<Airspace>`, minOccurs=0).
    public var airspaces: [HazardAirspace]

    /// Details of the hazardous area, if present (`<HazardousArea>`, minOccurs=0):
    /// e.g. a volcano's place name, coordinates and summit elevation.
    public var hazardousArea: HazardousArea?

    /// Free-text hazard particulars (`<HazardDetails>`, minOccurs=0).
    public var hazardDetails: String?

    /// The observed extent of the hazard (`<Observation>`, minOccurs=0).
    public var observation: HazardExtent?

    /// Forecast extents of the hazard (`<Forecasts>/<Forecast>`, minOccurs=0).
    public var forecasts: [HazardExtent]

    /// Any remark (`<Remark>`, TextType, minOccurs=0), paragraphs joined by newlines.
    public var remark: String?

    /// The raw advisory message text (`<HazardAdvisoryText>`, TextType, minOccurs=0),
    /// paragraphs joined by newlines.
    public var advisoryText: String?

    /// Issuing office identifier (`@issuer`, key part 1): e.g. a VAAC or FIR code.
    public var issuer: String?

    /// Weather provider/channel (`@source`, key part 2).
    public var source: String?

    /// Advisory number (`@advisoryNumber`, key part 3): e.g. a VAA number.
    public var advisoryNumber: String?

    /// Start of validity (`@startValidTime`, xs:dateTime).
    public var startValidTime: String?

    /// End of validity (`@endValidTime`, xs:dateTime).
    public var endValidTime: String?

    /// Observation time (`@observationTime`, xs:dateTime, key part 4).
    public var observationTime: String?

    /// Next expected information (`@nextinfo`).
    public var nextInfo: String?

    /// Optional margin extending `startValidTime` (`@startApplicabilityTime`).
    public var startApplicabilityTime: String?

    /// Optional margin extending `endValidTime` (`@endApplicabilityTime`).
    public var endApplicabilityTime: String?

    /// Presentation ordering hint (`@sequence`, xs:nonNegativeInteger).
    public var sequence: Int?

    /// Unrecognized child elements preserved verbatim (`<xs:any namespace="##other">`
    /// plus any other unmodeled content).
    public var extensions: [CapturedElement]

    public init(hazardType: String? = nil,
                airspaces: [HazardAirspace] = [],
                hazardousArea: HazardousArea? = nil,
                hazardDetails: String? = nil,
                observation: HazardExtent? = nil,
                forecasts: [HazardExtent] = [],
                remark: String? = nil,
                advisoryText: String? = nil,
                issuer: String? = nil,
                source: String? = nil,
                advisoryNumber: String? = nil,
                startValidTime: String? = nil,
                endValidTime: String? = nil,
                observationTime: String? = nil,
                nextInfo: String? = nil,
                startApplicabilityTime: String? = nil,
                endApplicabilityTime: String? = nil,
                sequence: Int? = nil,
                extensions: [CapturedElement] = []) {
        self.hazardType = hazardType
        self.airspaces = airspaces
        self.hazardousArea = hazardousArea
        self.hazardDetails = hazardDetails
        self.observation = observation
        self.forecasts = forecasts
        self.remark = remark
        self.advisoryText = advisoryText
        self.issuer = issuer
        self.source = source
        self.advisoryNumber = advisoryNumber
        self.startValidTime = startValidTime
        self.endValidTime = endValidTime
        self.observationTime = observationTime
        self.nextInfo = nextInfo
        self.startApplicabilityTime = startApplicabilityTime
        self.endApplicabilityTime = endApplicabilityTime
        self.sequence = sequence
        self.extensions = extensions
    }
}

/// An affected airspace reference (`<Airspace>`).
public struct HazardAirspace: Sendable, Equatable {
    /// 4-letter ICAO code of the airspace (`@airspaceICAOCode`, optional).
    public var icaoCode: String?
    /// Airspace long name (`<AirspaceName>`, minOccurs=0): e.g. an FIR name.
    public var name: String?

    public init(icaoCode: String? = nil, name: String? = nil) {
        self.icaoCode = icaoCode
        self.name = name
    }
}

/// The hazardous area of an advisory (`<HazardousArea>`): typically a volcano.
public struct HazardousArea: Sendable, Equatable {
    /// Place name text (`<PlaceName>`, minOccurs=0): e.g. the volcano name.
    public var placeName: String?
    /// Region/country qualifier (`PlaceName/@areaName`).
    public var areaName: String?
    /// International volcano number (`@volcanoNumber`), for volcanic ash advisories.
    public var volcanoNumber: String?
    /// Latitude in seconds (`Coordinates/@latitude`); positive North, negative South.
    public var latitude: Double?
    /// Longitude in seconds (`Coordinates/@longitude`); positive East, negative West.
    public var longitude: Double?
    /// Summit/area elevation (`<Elevation>`, AltitudeType): a `<Value unit=>` quantity.
    public var elevation: ARINCAltitude?

    public init(placeName: String? = nil,
                areaName: String? = nil,
                volcanoNumber: String? = nil,
                latitude: Double? = nil,
                longitude: Double? = nil,
                elevation: ARINCAltitude? = nil) {
        self.placeName = placeName
        self.areaName = areaName
        self.volcanoNumber = volcanoNumber
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

/// An observed or forecast extent of the hazard (the shared shape of `<Observation>`
/// and each `<Forecast>`): a time stamp, an optional altitude band, and a geographic
/// shape preserved as a captured subtree.
public struct HazardExtent: Sendable, Equatable {
    /// Time of this extent: `Observation/@observationTime` or `Forecast/@forecastTime`.
    public var time: String?

    /// Lower altitude bound of applicability (`<Altitudes>/<Lower>`, AltitudeType).
    /// Also populated from a single `<Altitude>` carrying `upperLowerBound="lower"`.
    public var lowerAltitude: ARINCAltitude?

    /// Upper altitude bound of applicability (`<Altitudes>/<Upper>`, AltitudeType).
    /// Also populated from a single `<Altitude>` carrying `upperLowerBound="upper"`.
    public var upperAltitude: ARINCAltitude?

    /// Movement speed of the affected polygon, if given (`Geography/<MovementSpeed>`).
    public var movementSpeed: ARINCSpeed?

    /// Movement direction in degrees, if given (`Geography/<MovementDirection>`).
    public var movementDirection: Double?

    /// The raw `<Geography>` subtree (Polygon/Spot + coordinates), preserved verbatim:
    /// coordinates carry no measurement units and are left for the caller to decode.
    public var geography: CapturedElement?

    public init(time: String? = nil,
                lowerAltitude: ARINCAltitude? = nil,
                upperAltitude: ARINCAltitude? = nil,
                movementSpeed: ARINCSpeed? = nil,
                movementDirection: Double? = nil,
                geography: CapturedElement? = nil) {
        self.time = time
        self.lowerAltitude = lowerAltitude
        self.upperAltitude = upperAltitude
        self.movementSpeed = movementSpeed
        self.movementDirection = movementDirection
        self.geography = geography
    }
}
