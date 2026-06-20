# ARINC633Kit

A native Swift 6 library for reading **ARINC 633‑4** electronic flight‑folder / operational
flight data — flight plans, weather, NOTAMs, load & trim, crew, fuel, de‑icing, and the
rest of the message family — into strongly‑typed, `Sendable` value models. It is a
streaming (SAX‑based) parser with an open dispatch registry, a never‑drop capture
fallback, and a clean extension point for airline/vendor message types.

## Independent‑implementation notice

> This package is an original, clean‑room Swift implementation that reads and writes
> ARINC 633‑4–conformant XML. It does not include, redistribute, or reproduce ARINC
> Specification 633 or its XSD schemas, which are copyrighted by AEEC / SAE‑ITC. Users
> are assumed to hold their own license to the specification. All bundled test fixtures
> are synthetic and contain no real operational or crew data.

## Requirements

- Swift 6.0+
- iOS 18+ / macOS 15+
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (used only for the
  double‑zipped EFF container)

## Installation

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/ARINC633Kit.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "ARINC633Kit", package: "ARINC633Kit"),
        // Optional — only if you consume Lido SUPP AdditionalRemarks:
        // .product(name: "ARINC633KitSUPP", package: "ARINC633Kit"),
    ]),
]
```

## Quick start

Parse any ARINC 633‑4 document and switch over the typed result:

```swift
import ARINC633Kit

let data = try Data(contentsOf: url)
let message = try ARINC633Parser().parse(data: data)

switch message {
case let .flightPlan(plan):
    print(plan.header.versionNumber, plan.fuelHeader?.tripFuel as Any)
case let .loadAndTrimData(ltd):
    print(ltd.header.timestamp)
case let .notam(briefing):
    print(briefing)
case let .fuel(fuel):
    print("FUEL subtype:", fuel.messageSubtype ?? "?")
case let .captured(root):
    // Unregistered root element — preserved verbatim, never dropped.
    print("captured <\(root.name)> with \(root.children.count) children")
case let .custom(custom):
    print("custom message:", custom.rootElement)
default:
    break
}
```

The supplementary header is extracted uniformly for every message type — including the
optional `FlightKeyIdentifier` UUID and the LTD header variants
(`M633LTDHeader` / `M633LTDSupplementaryHeader`) — and is available on each typed model
(e.g. `plan.supplementaryHeader.flightKeyIdentifier`).

## Supported message types

Every official ARINC 633‑4 root element dispatches to a dedicated typed parser. Unknown
roots are preserved as `.captured`; integrator types arrive as `.custom`.

| Message type            | Root element(s)                                   | Result case          | Coverage |
|-------------------------|---------------------------------------------------|----------------------|----------|
| Flight Plan             | `FlightPlan`                                      | `.flightPlan`        | typed    |
| Load & Trim Data        | `LoadAndTrimData` (LTD header variants)           | `.loadAndTrimData`   | typed    |
| Airport Weather         | `AirportWeather`                                  | `.airportWeather`    | typed    |
| Crew List               | `CrewList`                                        | `.crewList`          | typed    |
| Electronic Flight Folder| `EFUSUB`, `EFDREP`                                | `.eff`               | typed    |
| NOTAM Briefing          | `NOTAMBriefing`                                   | `.notam`             | typed    |
| ATC Flight Plan (ICAO)  | `FlightPlanAtcIcao`                               | `.atcFlightPlan`     | typed    |
| ATIS                    | `ATIS`                                            | `.atis`              | typed    |
| RAIM Report             | `RAIMReport`                                      | `.raimReport`        | typed    |
| Pilot Reports           | `PIREPBriefing`                                   | `.pirepBriefing`     | typed    |
| Hazard Briefing         | `HazardBriefing`                                  | `.hazardBriefing`    | typed    |
| Organized Tracks        | `OrganizedTracks`                                 | `.organizedTracks`   | typed    |
| Airspace Data           | `AirspaceData`                                    | `.airspaceData`      | typed    |
| Passenger List          | `PaxList`                                         | `.paxList`           | typed    |
| Region Weather          | `RegionWeather`, `RegionWeatherBriefing`          | `.regionWeather`     | typed    |
| Upper Air Data          | `UpperAirData`                                    | `.upperAirData`      | typed    |
| Airport Data            | `AirportData`                                     | `.airportData`       | typed    |
| General Error           | `GERIND`                                          | `.generalError`      | typed    |
| Weight & Balance Amend. | `WIFSUB`, `WIISUB`, `WIMSUB`, `WIRREP`            | `.wba`               | typed    |
| Fuel                    | `FCAIND`,`FDAACK`,`FDACOM`,`FDASUB`,`FENIND`,`FERIND`,`FORACK`,`FORSUB`,`FPRREP`,`FRCACK`,`FRCSUB`,`FSTREP`,`FSTREQ`,`FTBIND`,`FTEIND`,`FTIIND` | `.fuel` | typed |
| De‑Icing                | `DORACK`,`DORIND`,`DORSUB`,`DPRREP`,`DRCACK`,`DRCSUB` | `.deIcing`        | typed    |
| _any other root_        | _(unregistered)_                                  | `.captured`          | captured |
| _integrator types_      | _(registered via custom API)_                     | `.custom`            | custom   |

The family messages (WBA / FUEL / De‑Icing) share one payload model each and carry the
concrete subtype in `messageSubtype` (the root element name).

> **Safety‑relevant fields** — fuel, weights, CG, ETOPS, crew currency — preserve their
> units via the Foundation value types (`ARINCWeight`, `ARINCDistance`, `ARINCAltitude`,
> …) and are flagged in the in‑code documentation. Handle them with care.

## Extending: airline / vendor message types

Dispatch is driven by a value‑semantic `ARINC633MessageRegistry`. Register a handler for
your root element(s); it never disturbs the built‑ins:

```swift
import ARINC633Kit

struct MyAirlineBriefing: ARINC633CustomMessage {
    var rootElement: String { "MYAIRLINEROOT" }
    var payload: String
}

final class MyAirlineParser {
    func parse(data: Data) throws -> MyAirlineBriefing {
        let root = try GenericElementParser().parse(data: data)   // schema-agnostic tree
        return MyAirlineBriefing(payload: root.firstDescendant(named: "Payload")?.text ?? "")
    }
}

let registry = ARINC633MessageRegistry.standard
    .registering("MYAIRLINEROOT") { .custom(try MyAirlineParser().parse(data: $0)) }

let message = try ARINC633Parser(registry: registry).parse(data: xml)
if case let .custom(custom) = message, let mine = custom as? MyAirlineBriefing {
    print(mine.payload)
}
```

### Handling custom fields inside a known message

Typed models carry an `extensions: [CapturedElement]` bag. Any child element a parser does
not recognize (e.g. an airline customization inside an otherwise‑standard message) is
preserved there instead of being dropped, and is queryable:

```swift
if case let .atis(atis) = message {
    for ext in atis.bulletins.flatMap(\.extensions) {
        print(ext.name, ext.attributes, ext.firstDescendant(named: "Foo")?.text as Any)
    }
}
```

### Lido SUPP (optional module)

`AdditionalRemarks` is a Lido/vendor SUPP extension — **not** part of ARINC 633‑4 core. It
lives in the optional `ARINC633KitSUPP` product and surfaces through the `.custom` path:

```swift
import ARINC633Kit
import ARINC633KitSUPP

let parser = ARINC633Parser.withSUPP()           // .standard + SUPP types
if case let .custom(custom) = try parser.parse(data: xml),
   let remarks = custom as? AdditionalRemarks {
    print(remarks.crewQualifications, remarks.cduPreflight as Any)
}
```

## Architecture

- **`SAXParserEngine`** — base `XMLParserDelegate` with element‑stack tracking and
  character buffering. Namespaces are processed; matching is on **local element names**.
- **`HeaderAwareSAXParser`** — base that centralizes (and hardens) ARINC 633 envelope
  parsing so payload parsers stay focused.
- **`GenericElementParser` → `CapturedElement`** — a schema‑agnostic tree capture. Backs
  both the `.captured` fallback (nothing is ever dropped) and the per‑model `extensions`
  bags. Typed parsers are written as straightforward tree‑walks over it, with reusable
  envelope/value helpers (`makeARINC633Header()`, `valueAndUnit()`, `altitude(of:)`, …).
- **`ARINC633MessageRegistry`** — open, `Sendable`, value‑semantic root‑element → handler
  dispatch. `.standard` registers all built‑ins; `.registering(_:_:)` adds custom types.
- **`ARINC633Message`** — one case per message type, plus `.captured` and `.custom`.
- **Foundation value types** — `ARINC633Duration`, `ARINCCoordinate`,
  `ARINC633Measurement` (weight/distance/altitude/speed/temperature/…), `EstimatedActual`,
  and the shared enums. Reused everywhere to preserve units and value semantics.
- **EFF** — `ZIPFoundation` handles the double‑zipped Electronic Flight Folder container;
  inner products are dispatched through the same registry.

## Testing

```bash
swift test --build-system native
```

> `--build-system native` is recommended on macOS: the newer SwiftBuild system codesigns
> the `.xctest` bundle and can fail on filesystem extended attributes (e.g. when the repo
> lives under `~/Desktop`/iCloud). The native build system avoids that codesign step.

All committed fixtures are **synthetic** hand‑authored XML (fictional carrier, fake
registrations/UUIDs).

### Local‑only spec validation harness

`Tests/ARINC633KitTests/SpecValidationHarness.swift` parses **every** official sample in a
local, gitignored spec folder and reports, per file, whether it dispatched to a typed
parser, whether it threw, and which elements were captured but not explicitly modeled
(gap detection via the `extensions` bags). It **no‑ops when the spec folder is absent**, so
it is safe to keep committed and never embeds spec content. Point it at your licensed copy:

```bash
ARINC633_SPEC_DIR="/path/to/633-4" swift test --build-system native --filter SpecValidationHarness
```

or place the spec at `<package>/633-4 2` (gitignored by default).

## License

See [`LICENSE`](LICENSE). _(A library license — MIT or Apache‑2.0 — should be chosen before
publication; the current file is a clearly‑marked placeholder.)_
