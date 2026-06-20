// ATIS.swift
// ARINC633Kit
//
// Typed model for the ATIS (Automatic Terminal Information Service) message.
// Source: ATIS.xsd (root <ATIS>), samples ATIS_1..5.xml.
//
// Structure: <ATIS> -> <ATISBulletins> -> one <ATISBulletin> per airport, each with
// an <Airport>, optional <ATISDetails> (approaches, runways in use, observation,
// transition level, free-text operational notes) and an <ATISText> human-readable
// rendering. The embedded <Observation> is the AirportWeather observation type; it is
// preserved here as a captured subtree (use AirportWeatherParser if structured
// weather is required).

import Foundation

/// A parsed ATIS message: terminal information bulletins for one or more airports.
public struct ATISMessage: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// One bulletin per airport (`<ATISBulletins>/<ATISBulletin>`).
    public var bulletins: [ATISBulletin]

    /// Unrecognized child elements preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                bulletins: [ATISBulletin] = [],
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.bulletins = bulletins
        self.extensions = extensions
    }
}

/// ATIS information for a single airport (`<ATISBulletin>`).
public struct ATISBulletin: Sendable, Equatable {
    /// Airport ICAO code (`<Airport>/<AirportICAOCode>`).
    public var airportICAO: String?
    /// Airport IATA code, if present.
    public var airportIATA: String?
    /// Human-readable airport name (`Airport/@airportName`).
    public var airportName: String?

    /// Arrival/Departure indicator (`@departureType`: true=departure, false=arrival/general).
    public var isDeparture: Bool?
    /// Demand/contract indicator (`@demandType`: true=demand, false=contract).
    public var isDemand: Bool?
    /// Single-character information identifier (`@informationIndicator`, e.g. "P").
    public var informationIndicator: String?
    /// Observation time (`@observationTime`, from the observation attribute group).
    public var observationTime: String?
    /// Observation type (`@observationType`, e.g. "METAR").
    public var observationType: String?
    /// Display ordering hint (`@sequence`).
    public var sequence: Int?

    /// Expected approaches (`<ATISDetails>/<ExpectedApproaches>`).
    public var expectedApproaches: [ATISExpectedApproach]
    /// Runways in use (`<ATISDetails>/<Runways>`).
    public var runwaysInUse: [ATISRunway]
    /// Significant runway condition free-text, if any.
    public var significantRunwayCondition: String?
    /// Transition level (`<TransitionLevel>`, altitude with unit, often "ft/100").
    public var transitionLevel: ARINCAltitude?
    /// Expected holding delay free-text.
    public var holdingDelay: String?
    /// Other essential operational information free-text.
    public var otherEssentialOperationalInformation: String?
    /// Comment free-text.
    public var comment: String?
    /// The raw `<Observation>` weather subtree, preserved (see type note).
    public var observation: CapturedElement?
    /// Human-readable ATIS text (`<ATISText>`), paragraphs joined by newlines.
    public var atisText: String?

    public init(airportICAO: String? = nil,
                airportIATA: String? = nil,
                airportName: String? = nil,
                isDeparture: Bool? = nil,
                isDemand: Bool? = nil,
                informationIndicator: String? = nil,
                observationTime: String? = nil,
                observationType: String? = nil,
                sequence: Int? = nil,
                expectedApproaches: [ATISExpectedApproach] = [],
                runwaysInUse: [ATISRunway] = [],
                significantRunwayCondition: String? = nil,
                transitionLevel: ARINCAltitude? = nil,
                holdingDelay: String? = nil,
                otherEssentialOperationalInformation: String? = nil,
                comment: String? = nil,
                observation: CapturedElement? = nil,
                atisText: String? = nil) {
        self.airportICAO = airportICAO
        self.airportIATA = airportIATA
        self.airportName = airportName
        self.isDeparture = isDeparture
        self.isDemand = isDemand
        self.informationIndicator = informationIndicator
        self.observationTime = observationTime
        self.observationType = observationType
        self.sequence = sequence
        self.expectedApproaches = expectedApproaches
        self.runwaysInUse = runwaysInUse
        self.significantRunwayCondition = significantRunwayCondition
        self.transitionLevel = transitionLevel
        self.holdingDelay = holdingDelay
        self.otherEssentialOperationalInformation = otherEssentialOperationalInformation
        self.comment = comment
        self.observation = observation
        self.atisText = atisText
    }
}

/// An expected approach for an ATIS bulletin (`<ExpectedApproach>`).
public struct ATISExpectedApproach: Sendable, Equatable {
    /// Approach type (`@approachType`, e.g. "ILS").
    public var approachType: String?
    /// Runways associated with this approach.
    public var runways: [ATISRunway]

    public init(approachType: String? = nil, runways: [ATISRunway] = []) {
        self.approachType = approachType
        self.runways = runways
    }
}

/// A runway reference in an ATIS bulletin (`<Runway>`).
public struct ATISRunway: Sendable, Equatable {
    /// Runway designator (`@runwayIdentifier`, e.g. "25L").
    public var runwayIdentifier: String
    /// Optional usage type (`@type`: "Landing" / "Takeoff").
    public var type: String?

    public init(runwayIdentifier: String, type: String? = nil) {
        self.runwayIdentifier = runwayIdentifier
        self.type = type
    }
}
