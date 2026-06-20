// ARINC633MessageRegistry.swift
// ARINC633Kit
//
// Open, value-semantic dispatch from a root element name to a parsing handler.
// `.standard` registers every built-in ARINC 633-4 message type; integrators add
// their own with `registering(_:_:)`. `ARINC633Parser` looks up a handler by the
// document's root element and falls back to `.captured` when none is registered.

import Foundation

/// Maps an XML root element name to a handler that parses the document into an
/// `ARINC633Message`.
///
/// The registry has value semantics and is `Sendable`, so it can be customized and
/// passed across concurrency domains freely:
///
/// ```swift
/// let registry = ARINC633MessageRegistry.standard
///     .registering(["MYAIRLINEROOT"]) { data in
///         .custom(try MyAirlineParser().parse(data: data))
///     }
/// let message = try ARINC633Parser(registry: registry).parse(data: xml)
/// ```
///
/// Registering a custom root never disturbs the built-ins; registering an existing
/// root overrides it (last registration wins).
public struct ARINC633MessageRegistry: Sendable {

    /// A handler parses raw XML data (already known to have a given root) into a message.
    public typealias Handler = @Sendable (Data) throws -> ARINC633Message

    private var handlers: [String: Handler]

    /// Create a registry from an explicit handler map. Most callers use `.standard`.
    public init(handlers: [String: Handler] = [:]) {
        self.handlers = handlers
    }

    /// Look up the handler registered for a root element name, if any.
    public func handler(for rootElement: String) -> Handler? {
        handlers[rootElement]
    }

    /// All root element names with a registered handler.
    public var registeredRootElements: [String] {
        Array(handlers.keys)
    }

    /// Return a copy with `handler` registered for each of `rootElements`.
    ///
    /// Additive and non-mutating — the receiver is unchanged. Existing entries for
    /// the same root are overridden in the returned copy.
    public func registering(_ rootElements: [String], _ handler: @escaping Handler) -> ARINC633MessageRegistry {
        var copy = handlers
        for root in rootElements {
            copy[root] = handler
        }
        return ARINC633MessageRegistry(handlers: copy)
    }

    /// Convenience for a single root element.
    public func registering(_ rootElement: String, _ handler: @escaping Handler) -> ARINC633MessageRegistry {
        registering([rootElement], handler)
    }

    // MARK: - Standard registry

    /// The standard registry covering every built-in ARINC 633-4 root element.
    public static var standard: ARINC633MessageRegistry {
        var h: [String: Handler] = [:]

        // -- Fully typed domain parsers --
        h["FlightPlan"] = { .flightPlan(try FlightPlanParser().parse(data: $0)) }
        h["LoadAndTrimData"] = { .loadAndTrimData(try LoadAndTrimDataParser().parse(data: $0)) }
        h["AirportWeather"] = { .airportWeather(try AirportWeatherParser().parse(data: $0)) }
        h["CrewList"] = { .crewList(try CrewListParser().parse(data: $0)) }
        h["NOTAMBriefing"] = { .notam(try NOTAMBriefingParser().parse(data: $0)) }
        h["FlightPlanAtcIcao"] = { .atcFlightPlan(try ATCFlightPlanParser().parse(data: $0)) }

        // -- EFF container (two product roots) --
        let effHandler: Handler = { .eff(try EFFParser().parse(data: $0)) }
        h["EFUSUB"] = effHandler
        h["EFDREP"] = effHandler

        // -- Fully typed parsers --
        h["ATIS"] = { .atis(try ATISParser().parse(data: $0)) }

        // -- Header-only stub handlers (promoted to full parsers incrementally) --
        h["RAIMReport"] = { data in
            let (header, supp, _, _) = try StubParser().parse(data: data)
            return .raimReport(RAIMReport(header: header, supplementaryHeader: supp))
        }
        h["PIREPBriefing"] = { data in
            let (header, supp, attrs, _) = try StubParser().parse(data: data)
            return .pirepBriefing(PIREPBriefing(
                header: header,
                supplementaryHeader: supp,
                creationTime: attrs["creationTime"],
                fullPackage: attrs["fullPackage"] == "true"
            ))
        }
        h["HazardBriefing"] = { data in
            let (header, supp, _, _) = try StubParser().parse(data: data)
            return .hazardBriefing(HazardBriefing(header: header, supplementaryHeader: supp))
        }
        h["OrganizedTracks"] = { data in
            let (header, supp, attrs, _) = try StubParser().parse(data: data)
            return .organizedTracks(OrganizedTracksMessage(
                header: header,
                supplementaryHeader: supp,
                trackMessageIdentifier: attrs["trackMessageIdentifier"],
                area: attrs["area"]
            ))
        }
        h["AirspaceData"] = { data in
            let (header, supp, _, _) = try StubParser().parse(data: data)
            return .airspaceData(AirspaceDataMessage(header: header, supplementaryHeader: supp))
        }

        // -- WBA family (shared payload, distinguished by root) --
        let wba: Handler = { data in
            let (header, supp, _, root) = try StubParser().parse(data: data)
            return .wba(WBAMessage(header: header, supplementaryHeader: supp, messageSubtype: root))
        }
        for root in WBAMessage.rootElements { h[root] = wba }

        // -- FUEL family --
        let fuel: Handler = { data in
            let (header, supp, _, root) = try StubParser().parse(data: data)
            return .fuel(FUELMessage(header: header, supplementaryHeader: supp, messageSubtype: root))
        }
        for root in FUELMessage.rootElements { h[root] = fuel }

        // -- De-Icing family --
        let deicing: Handler = { data in
            let (header, supp, _, root) = try StubParser().parse(data: data)
            return .deIcing(DeIcingMessage(header: header, supplementaryHeader: supp, messageSubtype: root))
        }
        for root in DeIcingMessage.rootElements { h[root] = deicing }

        // -- Generic header-only stub messages --
        h["PaxList"] = genericStub { .paxList($0) }
        h["UpperAirData"] = genericStub { .upperAirData($0) }
        h["AirportData"] = genericStub { .airportData($0) }
        h["GERIND"] = genericStub { .generalError($0) }
        let regionWeather = genericStub { .regionWeather($0) }
        h["RegionWeather"] = regionWeather
        h["RegionWeatherBriefing"] = regionWeather

        return ARINC633MessageRegistry(handlers: h)
    }

    /// Build a handler that runs `StubParser` and wraps the resulting `StubMessage`.
    private static func genericStub(_ wrap: @escaping @Sendable (StubMessage) -> ARINC633Message) -> Handler {
        { data in
            let (header, supp, attrs, root) = try StubParser().parse(data: data)
            return wrap(StubMessage(
                header: header,
                supplementaryHeader: supp,
                rootElement: root,
                rootAttributes: attrs
            ))
        }
    }
}
