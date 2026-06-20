// WBAParser.swift
// ARINC633Kit
//
// Parser for the Weight & Balance Amendment message family (roots <WIFSUB>, <WIISUB>,
// <WIMSUB>, <WIRREP>; WBA.xsd / WBAcommon.xsd).
//
// Implemented as a tree-walk over the captured document. The four root elements share a
// common payload schema and differ only by name, so a single parse routine populates the
// shared `WBAMessage`, setting `messageSubtype` to the root element name and filling only
// whichever overlapping subset of elements is actually present. Unrecognized top-level
// children are swept into `extensions` (nothing dropped).
//
// SAFETY: WBA weight figures are plain integers (schema `weightType`); their unit is the
// shared `<Units weightUnit>`. CG figures (DOCG/ZFCG/TOCG) are integers in 0.1% MAC. This
// parser propagates the message weight unit onto every `WBAWeight` it produces so callers
// never lose unit context.

import Foundation

/// Parses a WBA document (`<WIFSUB>`/`<WIISUB>`/`<WIMSUB>`/`<WIRREP>`) into a `WBAMessage`.
public final class WBAParser: Sendable {

    public init() {}

    /// Parse WBA XML into a typed `WBAMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> WBAMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = WBAMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            messageSubtype: root.name
        )

        // Units context — weight unit is propagated onto every weight figure below.
        if let unitsEl = root.first(named: "Units") {
            message.units = WBAUnits(
                weightUnit: unitsEl.attribute("weightUnit"),
                armLeverUnit: unitsEl.attribute("armLeverUnit"),
                volumeUnit: unitsEl.attribute("volumeUnit")
            )
        }
        let weightUnit = message.units?.weightUnit

        // Configuration: standalone <ConfigurationCode> (WIMSUB) or full <Configuration> (WIFSUB).
        message.configurationCode = root.first(named: "ConfigurationCode")?.text.trimmedOrNil
        if let configEl = root.first(named: "Configuration") {
            message.configuration = Self.configuration(from: configEl)
            // Mirror the nested code up for convenience if no standalone one was present.
            if message.configurationCode == nil {
                message.configurationCode = message.configuration?.configurationCode
            }
        }

        message.dryOperating = Self.weightCG(
            from: root.first(named: "DryOperating"),
            weightName: "DOW", cgName: "DOCG", unit: weightUnit
        )
        if let loadingEl = root.first(named: "Loading") {
            message.loading = Self.loading(from: loadingEl, unit: weightUnit)
        }
        if let payloadEl = root.first(named: "Payload") {
            message.payload = WBAPayload(
                totalPaxWeight: Self.weight(payloadEl.first(named: "TotalPaxWeight"), unit: weightUnit),
                totalCargoWeight: Self.weight(payloadEl.first(named: "TotalCargoWeight"), unit: weightUnit),
                totalTrafficWeight: Self.weight(payloadEl.first(named: "TotalTrafficWeight"), unit: weightUnit)
            )
        }
        message.zeroFuelCGTarget = Self.weightCG(
            from: root.first(named: "ZF_CGTarget"),
            weightName: "ZFW", cgName: "ZFCG", unit: weightUnit
        )
        message.takeoffCheck = Self.weightCG(
            from: root.first(named: "TO_Check"),
            weightName: "TOW", cgName: "TOCG", unit: weightUnit
        )

        if let crewEl = root.first(named: "CrewNumber") {
            message.crewNumber = WBACrewNumber(
                cockpitCrew: crewEl.first(named: "CockpitCrew")?.intValue,
                cabinCrew: crewEl.first(named: "CabinCrew")?.intValue,
                cabinCrewMale: crewEl.first(named: "CabinCrewMale")?.intValue,
                cabinCrewFemale: crewEl.first(named: "CabinCrewFemale")?.intValue
            )
        }

        // PaxPerClass/TotalPaxNumber/Pax+CargoDistribution live inside <Payload>; use
        // firstDescendant so they resolve whether nested or (defensively) at root.
        message.paxPerClass = root.firstDescendant(named: "PaxPerClass")?.all(named: "Class").map(Self.classEntry) ?? []
        message.cabinVersion = root.firstDescendant(named: "CabinVersion")?.all(named: "Class").map(Self.classEntry) ?? []
        message.totalPaxNumber = root.firstDescendant(named: "TotalPaxNumber")?.intValue
        message.paxDistribution = root.firstDescendant(named: "PaxDistribution")?
            .all(named: "PaxPerSection").map(Self.paxSection) ?? []
        message.cargoDistribution = root.firstDescendant(named: "CargoDistribution")?
            .all(named: "CargoPerCompartment").map(Self.cargoCompartment) ?? []

        message.editionNumber = root.first(named: "EditionNumber")?.intValue
        message.checkedBy = root.first(named: "CheckedBy")?.text.trimmedOrNil
        message.balanceSeating = root.first(named: "BalanceSeating")?.text.trimmedOrNil
        if let lmcEl = root.first(named: "LMC") {
            message.lastMinuteChange = Self.lmc(from: lmcEl)
        }
        message.additionalInfo = root.first(named: "AdditionalInfo")?.text.trimmedOrNil

        // WIRREP downlink report content.
        message.errors = root.first(named: "WI_Error")?.all(named: "Error").map(Self.error) ?? []
        message.reportedMessage = root.first(named: "WI_Message")?.text.trimmedOrNil

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { !Self.mappedTopLevel.contains($0.name) }
        return message
    }

    /// Top-level payload element names this parser consumes (excluded from `extensions`).
    private static let mappedTopLevel: Set<String> = [
        "Units", "ConfigurationCode", "Configuration", "DryOperating", "Loading", "Payload",
        "ZF_CGTarget", "TO_Check", "CrewNumber", "PaxPerClass", "CabinVersion",
        "TotalPaxNumber", "PaxDistribution", "CargoDistribution", "EditionNumber",
        "CheckedBy", "BalanceSeating", "LMC", "AdditionalInfo", "WI_Error", "WI_Message"
    ]

    // MARK: - Element mappers

    /// A weight figure (`weightType` integer text) tagged with the message weight unit.
    private static func weight(_ el: CapturedElement?, unit: String?) -> WBAWeight? {
        guard let v = el?.intValue else { return nil }
        return WBAWeight(value: v, unit: unit)
    }

    /// A `<weight>` + `<cg>` pair (DryOperating / ZF_CGTarget / TO_Check).
    private static func weightCG(from el: CapturedElement?,
                                 weightName: String, cgName: String,
                                 unit: String?) -> WBAWeightCG? {
        guard let el else { return nil }
        let w = weight(el.first(named: weightName), unit: unit)
        let cg = el.first(named: cgName)?.intValue
        guard w != nil || cg != nil else { return nil }
        return WBAWeightCG(weight: w, centreOfGravity: cg)
    }

    private static func loading(from el: CapturedElement, unit: String?) -> WBALoading {
        var loading = WBALoading()
        let zfw = weight(el.first(named: "ZFW"), unit: unit)
        let zfcg = el.first(named: "ZFCG")?.intValue
        if zfw != nil || zfcg != nil {
            loading.zeroFuel = WBAWeightCG(weight: zfw, centreOfGravity: zfcg)
        }
        loading.fuelOnBoard = weight(el.first(named: "FOB"), unit: unit)
        loading.taxiFuel = weight(el.first(named: "TaxiFuel"), unit: unit)
        loading.tripFuel = weight(el.first(named: "TripFuel"), unit: unit)
        loading.fuelDensity = el.first(named: "FuelDensity")?.doubleValue
        return loading
    }

    private static func configuration(from el: CapturedElement) -> WBAConfiguration {
        var config = WBAConfiguration(
            configurationCode: el.first(named: "ConfigurationCode")?.text.trimmedOrNil,
            entryMode: el.first(named: "EntryMode")?.text.trimmedOrNil,
            crewCode: el.first(named: "CrewCode")?.text.trimmedOrNil
        )
        if let catering = el.first(named: "Catering") {
            config.cateringCode = catering.first(named: "CateringCode")?.text.trimmedOrNil
            config.cateringDeviations = catering.all(named: "CateringDeviationPerGalleyZone").compactMap {
                guard let zone = $0.attribute("zone") else { return nil }
                return WBACateringDeviation(zone: zone, weight: $0.attribute("weight").flatMap { Int($0) })
            }
        }
        if let misc = el.first(named: "Miscellaneous") {
            config.miscellaneousCodes = misc.all(named: "MiscellaneousCode").compactMap { $0.text.trimmedOrNil }
            config.miscellaneousItems = misc.all(named: "MiscellaneousItem").compactMap {
                guard let designation = $0.attribute("designation") else { return nil }
                return WBAMiscellaneousItem(
                    designation: designation,
                    weight: $0.attribute("weight").flatMap { Int($0) },
                    horizontalArm: $0.attribute("hArm").flatMap { Double($0) }
                )
            }
        }
        return config
    }

    private static func classEntry(from el: CapturedElement) -> WBAClass {
        WBAClass(classId: el.attribute("classId"),
                 seats: el.attribute("classSeats").flatMap { Int($0) })
    }

    private static func paxSection(from el: CapturedElement) -> WBAPaxSection {
        let types = el.all(named: "PaxPerType").map {
            WBAPaxType(paxType: $0.attribute("PaxType"),
                       paxNumber: $0.attribute("PaxNumber").flatMap { Int($0) })
        }
        return WBAPaxSection(
            section: el.attribute("section") ?? "",
            paxNumber: el.attribute("sectionPaxNumber").flatMap { Int($0) },
            paxPerType: types
        )
    }

    private static func cargoCompartment(from el: CapturedElement) -> WBACargoCompartment {
        WBACargoCompartment(
            compartment: el.attribute("compartment") ?? "",
            weight: el.attribute("compartmentCargoWeight").flatMap { Int($0) }
        )
    }

    private static func lmc(from el: CapturedElement) -> WBALMC {
        let lines = el.all(named: "LMCLine").map { lineEl -> WBALMCLine in
            var line = WBALMCLine()
            let dest = lineEl.first(named: "LMCLineDestination")
            line.destinationICAO = dest?.firstDescendant(named: "AirportICAOCode")?.text.trimmedOrNil
            line.destinationIATA = dest?.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
            if let pax = lineEl.first(named: "LMCLinePax") {
                line.paxSection = pax.attribute("section")
                line.paxNumberDelta = pax.attribute("LMCPaxNumber").flatMap { Int($0) }
                line.weightDelta = pax.attribute("LMCWeight").flatMap { Int($0) }
            }
            if let cargo = lineEl.first(named: "LMCLineCargo") {
                line.cargoCompartment = cargo.attribute("compartment")
                line.weightDelta = cargo.attribute("LMCWeight").flatMap { Int($0) }
            }
            return line
        }
        return WBALMC(totalWeight: el.attribute("LMCTotalWeight").flatMap { Int($0) }, lines: lines)
    }

    private static func error(from el: CapturedElement) -> WBAError {
        WBAError(category: el.attribute("category"),
                 label: el.attribute("label"),
                 text: el.text.trimmedOrNil)
    }
}
