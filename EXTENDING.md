# Extending ARINC633Kit

Real‑world ARINC 633 feeds often carry content beyond the base specification: an airline’s
proprietary message type, or vendor‑specific child elements bolted onto an otherwise‑standard
message. ARINC633Kit is built so that content is **never silently dropped** and is always
reachable — and so you can promote any of it to first‑class typed models when you need to.

This guide covers the three situations you’ll hit, from least to most work.

## Which situation am I in?

| Your file has…                                                        | What the kit does by default            | What you do                                   |
|-----------------------------------------------------------------------|------------------------------------------|-----------------------------------------------|
| Extra **child elements** inside a standard message                    | Preserves them in that model’s `extensions` bag | Read them via the `CapturedElement` API ([§1](#1-custom-fields-inside-a-standard-message)) |
| A **whole message** with a root element the kit doesn’t know          | Returns `.captured(CapturedElement)` — the full tree | Consume `.captured`, or register a typed handler ([§2](#2-a-custom-message-type-unknown-root-element)) |
| A **vendor variant** of a standard message you want parsed your way   | Uses the built‑in parser                 | Override the handler in the registry ([§3](#3-overriding-a-built-in-message-type)) |

Everything is driven by one value‑semantic type, `ARINC633MessageRegistry`, and a schema‑agnostic
tree type, `CapturedElement`.

---

## 1. Custom fields inside a standard message

When a typed parser meets a child element it doesn’t recognize, it puts the whole subtree into an
`extensions: [CapturedElement]` bag on the relevant model (the top‑level message and, for several
messages, nested models too). Nothing is lost; you query it directly.

```swift
import ARINC633Kit

let message = try ARINC633Parser().parse(data: xml)

if case let .atis(atis) = message {
    // Top-level extensions, plus per-bulletin extensions.
    let allExtras = atis.extensions + atis.bulletins.flatMap(\.extensions)

    for ext in allExtras {
        print(ext.name, ext.attributes)
        if ext.name == "AcmeProprietaryTag" {
            let code = ext.attribute("code")
            let note = ext.firstDescendant(named: "Note")?.text
            print("Acme:", code ?? "-", note ?? "-")
        }
    }
}
```

### `CapturedElement` query API

A `CapturedElement` is a node in a preserved XML subtree: a local `name`, an `attributes`
dictionary, owned `text`, and ordered `children`. Namespaces are processed away — you match on
**local element names**.

| Member                            | Returns                | Use for                                            |
|-----------------------------------|------------------------|----------------------------------------------------|
| `name`                            | `String`               | The element’s local name                           |
| `attributes`                      | `[String: String]`     | All attributes                                     |
| `attribute(_:)`                   | `String?`              | One attribute by name                              |
| `text`                            | `String`               | Trimmed text owned by this element                 |
| `children`                        | `[CapturedElement]`    | Direct children, in document order                 |
| `first(named:)`                   | `CapturedElement?`     | First **direct child** with a name                 |
| `all(named:)`                     | `[CapturedElement]`    | All direct children with a name                    |
| `firstDescendant(named:)`         | `CapturedElement?`     | First match **anywhere** in the subtree            |
| `text(ofChild:)`                  | `String?`              | Text of the first direct child with a name         |

For numeric and unit‑bearing content there are convenience accessors (the same ones the built‑in
parsers use):

| Member                | Returns                          | Use for                                                |
|-----------------------|----------------------------------|--------------------------------------------------------|
| `intValue`            | `Int?`                           | This element’s text as an `Int`                        |
| `doubleValue`         | `Double?`                        | This element’s text as a `Double`                      |
| `valueAndUnit()`      | `(value: Double, unit: String?)?`| A `<Value unit="…">N</Value>` (self or a descendant)   |
| `weight(of:)`         | `ARINCWeight?`                   | A named descendant’s `<Value>` as a weight             |
| `distance(of:)`       | `ARINCDistance?`                 | …as a distance                                         |
| `altitude(of:)`       | `ARINCAltitude?`                 | …as an altitude                                        |
| `speed(of:)`          | `ARINCSpeed?`                    | …as a speed                                            |
| `temperature(of:)`    | `ARINCTemperature?`              | …as a temperature                                      |

```swift
// <AcmeFuelMargin><Value unit="kg">1200</Value></AcmeFuelMargin>
let margin = ext.weight(of: "AcmeFuelMargin")     // ARINCWeight? (unit preserved)
```

---

## 2. A custom message type (unknown root element)

If a document’s **root element** has no registered handler, the kit parses it into a full
`CapturedElement` tree and returns `.captured`. You get something useful with zero extra code:

```swift
if case let .captured(root) = try ARINC633Parser().parse(data: xml) {
    print("Unknown root <\(root.name)>")
    let value = root.firstDescendant(named: "SomeField")?.text
}
```

When you want a real typed model instead, register a handler.

### Step 1 — Define your model

Conform a `Sendable` value type to `ARINC633CustomMessage` (its `rootElement` is the XML root the
message comes from):

```swift
import ARINC633Kit

public struct AcmeWeatherSummary: ARINC633CustomMessage {
    public var rootElement: String { "AcmeWeatherSummary" }

    public var station: String?
    public var temperature: ARINCTemperature?
    public var remarks: [String]

    /// Preserve anything you don't model, same as the built-ins.
    public var extensions: [CapturedElement] = []
}
```

### Step 2 — Write a parser (tree‑walk — the recommended style)

Use `GenericElementParser` to get the tree, then map it. The reusable helpers extract the standard
ARINC 633 envelope and unit‑bearing values for you:

```swift
public struct AcmeWeatherParser {
    public init() {}

    public func parse(data: Data) throws -> AcmeWeatherSummary {
        let root = try GenericElementParser().parse(data: data)

        var msg = AcmeWeatherSummary(
            station: root.firstDescendant(named: "Station")?.text,
            temperature: root.temperature(of: "AirTemperature"),
            remarks: root.all(named: "Remark").map(\.text)
        )

        // If your message uses the standard <M633Header>/<M633SupplementaryHeader>,
        // pull the envelope out with the same helpers the built-ins use:
        let header = root.makeARINC633Header()
        let supp   = root.makeSupplementaryHeader()
        _ = (header, supp)   // store on your model as desired

        // Sweep anything you didn't map into extensions (nothing dropped):
        let modeled: Set<String> = ["Station", "AirTemperature", "Remark"]
        msg.extensions = root.payloadChildren.filter { !modeled.contains($0.name) }
        return msg
    }
}
```

> Tip: `payloadChildren` is `children` minus the envelope elements (`M633Header`,
> `M633SupplementaryHeader`, and the LTD variants), so it’s the right starting point for a sweep.

### Step 3 — Register it and parse

`ARINC633MessageRegistry` has value semantics; `registering` returns a new registry and never
disturbs the built‑ins. Your handler returns `.custom(...)`.

```swift
let registry = ARINC633MessageRegistry.standard
    .registering("AcmeWeatherSummary") { data in
        .custom(try AcmeWeatherParser().parse(data: data))
    }

let parser = ARINC633Parser(registry: registry)

switch try parser.parse(data: xml) {
case let .custom(custom as AcmeWeatherSummary):
    print(custom.station ?? "-", custom.temperature as Any)
case let .custom(other):
    print("some other custom type:", other.rootElement)
default:
    break
}
```

Register several roots at once by passing an array — handy for a message family that shares one
payload but uses several root element names:

```swift
let registry = ARINC633MessageRegistry.standard
    .registering(["ACMSUB", "ACMACK", "ACMREP"]) { data in
        .custom(try AcmeParser().parse(data: data))   // distinguish by root inside the parser
    }
```

---

## 3. Overriding a built‑in message type

Registering a root that already exists **replaces** that handler in the returned registry (last
registration wins), leaving every other built‑in untouched. Use this when your provider emits a
non‑standard variant of a standard message that you want parsed your way:

```swift
let registry = ARINC633MessageRegistry.standard
    .registering("NOTAMBriefing") { data in
        .custom(try MyNotamParser().parse(data: data))   // your parser instead of the built-in
    }
```

You can also build a registry from scratch (`ARINC633MessageRegistry(handlers:)`) if you want to
support only a subset of message types.

---

## Reusable helpers reference

When writing a custom parser, lean on the same building blocks the built‑in parsers use:

- `GenericElementParser().parse(data:) -> CapturedElement` — schema‑agnostic full‑tree capture.
- `CapturedElement.makeARINC633Header()` / `.makeSupplementaryHeader()` — extract the standard or
  LTD envelope (version, timestamp, `FlightKeyIdentifier`, flight/airport/aircraft fields).
- `CapturedElement.payloadChildren` — children excluding the envelope, for an extensions sweep.
- The value accessors in the tables above — for `<Value unit="…">` content with units preserved.

A complete, shipping example lives in the **`ARINC633KitSUPP`** module: it registers the Lido
vendor `AdditionalRemarks` message (root `<AdditionalRemarks>`) through exactly this custom‑handler
path and returns it as `.custom`. See `Sources/ARINC633KitSUPP/` —
`SUPPRegistry.swift` (the `registeringSUPP()` extension) and `AdditionalRemarksParser.swift`.

```swift
import ARINC633Kit
import ARINC633KitSUPP

let parser = ARINC633Parser.withSUPP()             // .standard + SUPP types
if case let .custom(custom as AdditionalRemarks) = try parser.parse(data: xml) {
    print(custom.crewQualifications)
}
```

## Tips and gotchas

- **Local names, not namespaces.** Parsing runs with namespace processing on and matches on local
  element names. Match `"FlightPlan"`, not a namespaced/qualified name.
- **`Sendable` everywhere.** Custom messages and handlers must be `Sendable`. Keep models as value
  types; this is enforced by the compiler under Swift 6 strict concurrency.
- **Registries are cheap and immutable.** `registering` copies; share a configured registry across
  threads and reuse it for many `ARINC633Parser` instances.
- **Never drop content.** Mirror the built‑ins: give your custom models an `extensions` bag and
  sweep unmapped children into it, so future provider additions survive untouched.
- **Decide between `.captured` and `.custom`.** `.captured` is free and fine for occasional or
  exploratory content; promote to a registered `.custom` type once you depend on specific fields.
