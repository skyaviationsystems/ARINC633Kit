// OrganizedTracks.swift
// ARINC633Kit
//
// Typed model for the Organized Track System (OTS) message — e.g. the North
// Atlantic Track (NAT) system, PACOTS, etc.
//
// Source: OrganizedTracks.xsd (root <OrganizedTracks>) and RouteDefinition.xsd
// (RouteDefinitionType, the base type of each track). Reference is by element
// name only; no schema text is reproduced here.
//
// Structure: <OrganizedTracks> carries the standard envelope plus a set of tracks.
// Each track is a route definition: a lateral route (ordered waypoint sequence), an
// optional vertical route (applicable flight levels, grouped by direction), optional
// valid airports, recursive entry/exit connection segments, and free-text remarks.
// The schema wraps tracks in <OrganizedTracksSet>; published samples sometimes place
// <OrganizedTrack> directly under the root — both shapes are accepted by the parser.

import Foundation

/// A parsed Organized Track System message (e.g. North Atlantic Track system).
///
/// Source: OrganizedTracks.xsd, root `<OrganizedTracks>`.
public struct OrganizedTracksMessage: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// Track message identifier (`@trackMessageIdentifier`, e.g. "333"/"153").
    public let trackMessageIdentifier: String?

    /// Geographic area in which the tracks are defined
    /// (`@area`, e.g. "NorthAtlantic", "NAT", "PACOTS").
    public let area: String?

    /// The organized tracks (`<OrganizedTracksSet>/<OrganizedTrack>`, or
    /// `<OrganizedTrack>` directly under the root in some published samples).
    public var tracks: [RouteDefinition]

    /// Message-level remarks (`<Remarks>/<Remark>`), each rendered as joined text.
    public var remarks: [String]

    /// The original publication source of the tracks (`<OrganizedTrackMessage>`):
    /// either a NOTAM reference or free text. Preserved as a captured subtree because
    /// it is an `xs:choice` that also permits foreign (`##other`) content.
    public var organizedTrackMessage: CapturedElement?

    /// Raw textual rendering of the message, if a caller supplies one. Retained for
    /// backward compatibility with the previous header-only stub.
    public let rawContent: String?

    /// Unrecognized top-level payload children preserved verbatim
    /// (airline/vendor extensions). Nothing well-formed is dropped.
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                trackMessageIdentifier: String? = nil,
                area: String? = nil,
                tracks: [RouteDefinition] = [],
                remarks: [String] = [],
                organizedTrackMessage: CapturedElement? = nil,
                rawContent: String? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.trackMessageIdentifier = trackMessageIdentifier
        self.area = area
        self.tracks = tracks
        self.remarks = remarks
        self.organizedTrackMessage = organizedTrackMessage
        self.rawContent = rawContent
        self.extensions = extensions
    }
}

/// A route definition — the base of one organized track and of each connection
/// segment leading to or from it.
///
/// Source: RouteDefinition.xsd, `RouteDefinitionType`. The type is recursive:
/// entry/exit connections are themselves route definitions.
public struct RouteDefinition: Sendable, Equatable {
    /// Route identifier (`@routeIdentifier`, e.g. "A", "N22B", "Y53S").
    public var routeIdentifier: String?
    /// Publication time of the route data (`@revisionTime`, ISO 8601).
    public var revisionTime: String?
    /// Geographic area the route is defined in (`@area`, e.g. "NAT", "NAR", "EUR").
    public var area: String?
    /// Time the route becomes applicable (`@startValidTime`, ISO 8601).
    public var startValidTime: String?
    /// Time applicability ends (`@endValidTime`, ISO 8601).
    public var endValidTime: String?
    /// Free-text applicability conditions (`@trackApplicability`).
    public var trackApplicability: String?

    /// Connection role relative to the parent route, when this route definition is a
    /// connection segment (`Connection/@entryExit`, e.g. "entry"/"exit"). The schema
    /// instead nests connections under `<EntryConnections>`/`<ExitConnections>`; the
    /// parser maps both shapes, setting this field accordingly.
    public var entryExit: String?

    /// Ordered waypoint sequence of the lateral route
    /// (`<LateralRoute>/<RouteWaypoints>/<RouteWaypoint>`, or `<Waypoints>/<Waypoint>`
    /// in published samples).
    public var waypoints: [RouteWaypoint]

    /// Vertical route: applicable altitude groups, each tagged with a direction
    /// (`<VerticalRoute>/<Altitudes>`).
    public var altitudeGroups: [AltitudeGroup]

    /// Airports for which the route is valid (`<Airports>/<Airport>`).
    public var airports: [RouteAirport]

    /// Route segments leading onto / off of this route, themselves route definitions
    /// (`<EntryConnections>`/`<ExitConnections>/<Connection>`, or `<Connections>/<Connection>`).
    public var connections: [RouteDefinition]

    /// Route-level remarks (`<Remarks>/<Remark>`), each rendered as joined text.
    public var remarks: [String]

    public init(routeIdentifier: String? = nil,
                revisionTime: String? = nil,
                area: String? = nil,
                startValidTime: String? = nil,
                endValidTime: String? = nil,
                trackApplicability: String? = nil,
                entryExit: String? = nil,
                waypoints: [RouteWaypoint] = [],
                altitudeGroups: [AltitudeGroup] = [],
                airports: [RouteAirport] = [],
                connections: [RouteDefinition] = [],
                remarks: [String] = []) {
        self.routeIdentifier = routeIdentifier
        self.revisionTime = revisionTime
        self.area = area
        self.startValidTime = startValidTime
        self.endValidTime = endValidTime
        self.trackApplicability = trackApplicability
        self.entryExit = entryExit
        self.waypoints = waypoints
        self.altitudeGroups = altitudeGroups
        self.airports = airports
        self.connections = connections
        self.remarks = remarks
    }
}

/// One waypoint in a route's lateral sequence (`<RouteWaypoint>` / `<Waypoint>`).
///
/// Source: RouteDefinition.xsd, the RouteWaypoint local type.
public struct RouteWaypoint: Sendable, Equatable {
    /// Sequence number within the waypoint list (`@sequenceId`).
    public var sequenceId: Int?
    /// 1..5 char identifier as shown to the pilot / entered in the FMC (`@waypointId`).
    public var waypointId: String?
    /// Secondary identification (`@waypointName`, e.g. as in an ATC flight plan, or an
    /// artificial fix such as TOC/TOD).
    public var waypointName: String?
    /// Long-form waypoint name (`@waypointLongName`).
    public var waypointLongName: String?
    /// Country ICAO code (`@countryICAOCode`).
    public var countryICAOCode: String?

    /// Geographic position when `<Coordinates>` carries `@latitude`/`@longitude`
    /// (arc-seconds, converted to decimal degrees).
    public var coordinate: ARINCCoordinate?
    /// Raw text content of `<Coordinates>`, if present (some encodings put the position
    /// in the element body rather than the attribute pair).
    public var coordinatesText: String?

    /// Airway from the previous waypoint (`<Airway>` text, e.g. an airway/SID/STAR id).
    public var airway: String?
    /// Airway type (`<Airway>/@type`, e.g. "SID", "STAR", "RNAV", "Direct").
    public var airwayType: String?

    /// Waypoint functions (`<Functions>/<Function>` or repeated `<Function>`),
    /// e.g. "OceanicEntryPoint", "OceanicExitPoint", "CompulsoryReportingPoint",
    /// "TopOfClimb".
    public var functions: [String]

    public init(sequenceId: Int? = nil,
                waypointId: String? = nil,
                waypointName: String? = nil,
                waypointLongName: String? = nil,
                countryICAOCode: String? = nil,
                coordinate: ARINCCoordinate? = nil,
                coordinatesText: String? = nil,
                airway: String? = nil,
                airwayType: String? = nil,
                functions: [String] = []) {
        self.sequenceId = sequenceId
        self.waypointId = waypointId
        self.waypointName = waypointName
        self.waypointLongName = waypointLongName
        self.countryICAOCode = countryICAOCode
        self.coordinate = coordinate
        self.coordinatesText = coordinatesText
        self.airway = airway
        self.airwayType = airwayType
        self.functions = functions
    }
}

/// A direction-tagged group of applicable altitudes for a vertical route
/// (`<VerticalRoute>/<Altitudes>`).
///
/// Source: RouteDefinition.xsd (Altitudes extends AltitudeInfoType with `@direction`).
public struct AltitudeGroup: Sendable, Equatable {
    /// Direction for which these altitudes are valid (`@direction`, e.g. "westbound").
    public var direction: String?
    /// Individual applicable altitudes (`<Altitude>/<Value unit="...">`).
    public var altitudes: [ARINCAltitude]

    public init(direction: String? = nil, altitudes: [ARINCAltitude] = []) {
        self.direction = direction
        self.altitudes = altitudes
    }
}

/// An airport for which a route is valid (`<Airports>/<Airport>`).
///
/// Source: RouteDefinition.xsd via AirportIdentificationType (ICAO and/or IATA code).
public struct RouteAirport: Sendable, Equatable {
    /// 4-letter ICAO code (`<AirportICAOCode>`).
    public var icaoCode: String?
    /// 3-letter IATA code (`<AirportIATACode>`, minOccurs=0).
    public var iataCode: String?

    public init(icaoCode: String? = nil, iataCode: String? = nil) {
        self.icaoCode = icaoCode
        self.iataCode = iataCode
    }
}
