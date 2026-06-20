# ARINC633Kit

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2018%20%7C%20macOS%2015-0A84FF)](https://developer.apple.com)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-4BC51D)](https://www.swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)

A native Swift 6 library that parses **ARINC 633‑4** electronic flight‑folder / operational
flight data (flight plans, weather, NOTAMs, load & trim, crew, fuel, de‑icing, and the rest
of the message family) into strongly‑typed, `Sendable` value models.

It’s a streaming (SAX‑based) parser with an open dispatch registry, a never‑drop capture
fallback, and a clean extension point for airline and vendor message types.

```swift
let message = try ARINC633Parser().parse(data: xml)

if case let .flightPlan(plan) = message {
    print(plan.fuelHeader?.tripFuel ?? "—")   // typed, unit-preserving
}
```

## Features

- **Complete 633‑4 coverage** — every official root element parses into a dedicated typed model (45+ roots across 21 message families).
- **Nothing is ever dropped** — unknown roots become `.captured` trees; unrecognized children land in per‑model `extensions` bags.
- **Open & extensible** — register airline/vendor message types through a value‑semantic registry; they arrive as `.custom`.
- **Units preserved** — fuel, weights, distances, and altitudes keep their units via Foundation value types (`ARINCWeight`, `ARINCAltitude`, …).
- **Streaming SAX** — handles large (1 MB+, hundreds‑of‑NOTAMs) briefings efficiently.
- **Swift 6 strict concurrency** — everything is `Sendable`; models are value types.
- **Synthetic, exhaustive tests** — plus a local‑only harness that validates against the official sample corpus.

> [!IMPORTANT]
> **Independent, clean‑room implementation.** This package reads and writes ARINC 633‑4–conformant
> XML. It does **not** include, redistribute, or reproduce ARINC Specification 633 or its XSD
> schemas, which are copyrighted by AEEC / SAE‑ITC. Users are assumed to hold their own license to
> the specification. All bundled test fixtures are synthetic and contain no real operational or crew data.

## Requirements

| | |
|---|---|
| Swift | 6.0+ |
| Platforms | iOS 18+ · macOS 15+ |
| Dependencies | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (EFF container only) |

## Installation

Add the package to your `Package.swift`:

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

Or, in Xcode: **File ▸ Add Package Dependencies…** and paste the repository URL.

## Quick start

Parse any ARINC 633‑4 document and switch over the typed result:

```swift
import ARINC633Kit

let data = try Data(contentsOf: url)
let message = try ARINC633Parser().parse(data: data)

switch message {
case let .flightPlan(plan):
    print(plan.header.versionNumber, plan.fuelHeader?.tripFuel as Any)

case let .notam(briefing):
    for notam in briefing.notams {
        print(notam.subjects, notam.airports)
    }

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

The message envelope is extracted uniformly for every type — including the optional
`FlightKeyIdentifier` UUID and the LTD header variants (`M633LTDHeader` /
`M633LTDSupplementaryHeader`) — and is available on each typed model, e.g.
`plan.supplementaryHeader.flightKeyIdentifier`.

## Supported message types

Every official ARINC 633‑4 root element dispatches to a dedicated typed parser. Unknown roots
are preserved as `.captured`; integrator types arrive as `.custom`.

| Message type             | Root element(s)                                   | Result case        |
|--------------------------|---------------------------------------------------|--------------------|
| Flight Plan              | `FlightPlan`                                      | `.flightPlan`      |
| Load & Trim Data         | `LoadAndTrimData` (LTD header variants)           | `.loadAndTrimData` |
| Airport Weather          | `AirportWeather`                                  | `.airportWeather`  |
| Crew List                | `CrewList`                                        | `.crewList`        |
| Electronic Flight Folder | `EFUSUB`, `EFDREP`                                | `.eff`             |
| NOTAM Briefing           | `NOTAMBriefing`                                   | `.notam`           |
| ATC Flight Plan (ICAO)   | `FlightPlanAtcIcao`                               | `.atcFlightPlan`   |
| ATIS                     | `ATIS`                                            | `.atis`            |
| RAIM Report              | `RAIMReport`                                      | `.raimReport`      |
| Pilot Reports            | `PIREPBriefing`                                   | `.pirepBriefing`   |
| Hazard Briefing          | `HazardBriefing`                                  | `.hazardBriefing`  |
| Organized Tracks         | `OrganizedTracks`                                 | `.organizedTracks` |
| Airspace Data            | `AirspaceData`                                    | `.airspaceData`    |
| Passenger List           | `PaxList`                                         | `.paxList`         |
| Region Weather           | `RegionWeather`, `RegionWeatherBriefing`          | `.regionWeather`   |
| Upper Air Data           | `UpperAirData`                                    | `.upperAirData`    |
| Airport Data             | `AirportData`                                     | `.airportData`     |
| General Error            | `GERIND`                                          | `.generalError`    |
| Weight & Balance Amend.  | `WIFSUB`, `WIISUB`, `WIMSUB`, `WIRREP`            | `.wba`             |
| Fuel                     | `FCAIND`, `FDAACK`, `FDACOM`, `FDASUB`, `FENIND`, `FERIND`, `FORACK`, `FORSUB`, `FPRREP`, `FRCACK`, `FRCSUB`, `FSTREP`, `FSTREQ`, `FTBIND`, `FTEIND`, `FTIIND` | `.fuel` |
| De‑Icing                 | `DORACK`, `DORIND`, `DORSUB`, `DPRREP`, `DRCACK`, `DRCSUB` | `.deIcing` |
| _any other root_         | _(unregistered)_                                  | `.captured`        |
| _integrator types_       | _(registered via custom API)_                     | `.custom`          |

The family messages (WBA / FUEL / De‑Icing) share one payload model each and carry the
concrete subtype in `messageSubtype` (the root element name).

> [!NOTE]
> **Safety‑relevant fields** — fuel, weights, CG, ETOPS, crew currency — preserve their units via
> the Foundation value types and are flagged in the in‑code documentation. Handle them with care.

## Extending

> Got a 633 feed with custom content — a proprietary message type, or vendor‑specific fields inside
> a standard message? See the **[Extending guide](EXTENDING.md)** for a full walkthrough (custom
> message types, reading custom fields, overriding built‑ins, and the `CapturedElement` query API).

Dispatch is driven by a value‑semantic `ARINC633MessageRegistry`. Register a handler for your
root element(s); it never disturbs the built‑ins.

```swift
import ARINC633Kit

struct MyAirlineBriefing: ARINC633CustomMessage {
    var rootElement: String { "MYAIRLINEROOT" }
    var payload: String
}

let registry = ARINC633MessageRegistry.standard
    .registering("MYAIRLINEROOT") { data in
        let root = try GenericElementParser().parse(data: data)   // schema-agnostic tree
        return .custom(MyAirlineBriefing(payload: root.firstDescendant(named: "Payload")?.text ?? ""))
    }

let message = try ARINC633Parser(registry: registry).parse(data: xml)
if case let .custom(custom) = message, let mine = custom as? MyAirlineBriefing {
    print(mine.payload)
}
```

### Custom fields inside a known message

Typed models carry an `extensions: [CapturedElement]` bag. Any child element a parser doesn’t
recognize is preserved there and stays queryable instead of being dropped:

```swift
if case let .atis(atis) = message {
    for ext in atis.bulletins.flatMap(\.extensions) {
        print(ext.name, ext.attributes, ext.firstDescendant(named: "Foo")?.text as Any)
    }
}
```

### Lido SUPP (optional module)

`AdditionalRemarks` is a Lido/vendor SUPP extension — **not** part of ARINC 633‑4 core. It lives
in the optional `ARINC633KitSUPP` product and surfaces through the `.custom` path:

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

| Component | Role |
|---|---|
| `SAXParserEngine` | Base `XMLParserDelegate` with element‑stack tracking + character buffering. Namespaces processed; matching on **local element names**. |
| `HeaderAwareSAXParser` | Centralizes (and hardens) ARINC 633 envelope parsing so payload parsers stay focused. |
| `GenericElementParser` -> `CapturedElement` | Schema‑agnostic tree capture. Backs the `.captured` fallback and the `extensions` bags. New typed parsers are written as tree‑walks over it, with reusable envelope/value helpers. |
| `ARINC633MessageRegistry` | Open, `Sendable`, value‑semantic root‑element -> handler dispatch. `.standard` registers all built‑ins; `.registering(_:_:)` adds custom types. |
| `ARINC633Message` | One case per message type, plus `.captured` and `.custom`. |
| Foundation value types | `ARINC633Duration`, `ARINCCoordinate`, `ARINC633Measurement` (weight / distance / altitude / speed / temperature / …), `EstimatedActual`, shared enums. Reused everywhere to preserve units. |
| EFF container | `ZIPFoundation` unpacks the double‑zipped Electronic Flight Folder; inner products dispatch through the same registry. |

## Testing

```bash
swift test --build-system native
```

> [!TIP]
> Use `--build-system native` on macOS. The newer SwiftBuild system codesigns the `.xctest`
> bundle and can fail on filesystem extended attributes (e.g. when the checkout lives under
> `~/Desktop` or iCloud). The native build system skips that step.

All committed fixtures are **synthetic** hand‑authored XML (fictional carrier, fake
registrations/UUIDs).

### Local‑only spec validation harness

`SpecValidationHarness` parses **every** official sample in your licensed spec copy and reports,
per file, whether it dispatched to a typed parser, whether it threw, and which elements were
preserved in an `extensions` bag rather than mapped to a typed field. It **no‑ops when the spec
folder is absent** and never embeds spec content.

The copyrighted spec is kept **outside the repository** (so the repo holds only publishable
content). The harness finds it automatically at `../ARINC633Kit-local/633-4 2`, or point it
anywhere:

```bash
ARINC633_SPEC_DIR="/path/to/633-4" swift test --build-system native --filter SpecValidationHarness
```

## Coverage

All 21 message families parse the full official sample corpus into typed models without
throwing. Every element present in those samples is either mapped to a typed field or
preserved in an `extensions` bag — nothing well‑formed is dropped. A few deeply nested
sub‑structures (an ATIS/region weather `Observation`, NOTAM/hazard geometry) are intentionally
surfaced as queryable `CapturedElement` subtrees rather than re‑typing the entire weather or
geometry vocabulary; they remain fully accessible via the `CapturedElement` query API.

## License

Licensed under the **Apache License, Version 2.0** — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
This license covers the library code only; it grants no rights to the ARINC Specification 633
itself, which is copyrighted by AEEC / SAE‑ITC and is not redistributed by this project.
