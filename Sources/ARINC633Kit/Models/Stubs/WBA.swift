// WBA.swift
// ARINC633Kit
//
// Typed model for the Weight & Balance Amendment (WBA) message family.
// Source: WBA.xsd (roots <WIFSUB>, <WIISUB>, <WIMSUB>, <WIRREP>) and WBAcommon.xsd.
//
// The four root elements share a common payload schema and are distinguished only by
// the root element name (`messageSubtype`). Each subtype carries an overlapping subset
// of the same elements:
//   - WIMSUB (Init-Submit, Minimal mode): Units, optional ConfigurationCode, Loading,
//     optional cross-checks/crew/pax/cargo distribution, AdditionalInfo.
//   - WIISUB (Init-Submit, Intermediate mode): adds DryOperating, Payload, EditionNumber,
//     CheckedBy, BalanceSeating, optional LMC.
//   - WIFSUB (Init-Submit, Full mode): adds full Configuration block.
//   - WIRREP (Error Report, downlink): WI_Error + WI_Message only, no W&B figures.
// This model holds the UNION of all those fields; subtype-specific fields are simply
// nil/empty when not present in a given message.
//
// SAFETY: weights and CG values in this model are safety-critical. Weight figures are
// integers expressed in the unit named by `units.weightUnit` (e.g. "kg"). CG figures
// (DOCG/ZFCG/TOCG) are integers in units of 0.1% MAC (Mean Aerodynamic Chord), i.e. a
// raw value of 326 denotes 32.6% MAC. Callers MUST apply the correct unit/scale.

import Foundation

/// A parsed Weight & Balance Amendment message (`<WIFSUB>`/`<WIISUB>`/`<WIMSUB>`/`<WIRREP>`).
public struct WBAMessage: Sendable, Equatable {
    /// Root elements that map to a WBA message (per WBA.xsd / WBAcommon.xsd).
    public static let rootElements = ["WIFSUB", "WIISUB", "WIMSUB", "WIRREP"]

    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context (`<M633SupplementaryHeader>`).
    public let supplementaryHeader: SupplementaryHeader

    /// WBA message subtype: the root element name (WIFSUB, WIISUB, WIMSUB, or WIRREP).
    public let messageSubtype: String?

    // MARK: - Units / configuration

    /// Unit context (`<Units>`): weight, arm-lever, and volume units that all numeric
    /// figures in this message are expressed in. Absent on WIRREP error reports.
    public var units: WBAUnits?

    /// Configuration code (`<ConfigurationCode>`) when supplied standalone (WIMSUB) or
    /// inside `<Configuration>` (WIFSUB). Identifies a config referenced in the WBA DB.
    public var configurationCode: String?

    /// Full configuration block (`<Configuration>`), present on WIFSUB.
    public var configuration: WBAConfiguration?

    // MARK: - Weight & balance figures

    /// Actual Dry Operating aircraft system (`<DryOperating>`: DOW + DOCG).
    public var dryOperating: WBAWeightCG?

    /// Loading data (`<Loading>`): zero-fuel weight/CG plus fuel figures.
    public var loading: WBALoading?

    /// Payload data (`<Payload>`): pax/cargo breakdown and total traffic weight.
    public var payload: WBAPayload?

    /// Estimated Zero-Fuel target provided to the refuel application (`<ZF_CGTarget>`).
    public var zeroFuelCGTarget: WBAWeightCG?

    /// Take-off cross-check figures (`<TO_Check>`: TOW + TOCG) for cockpit comparison.
    public var takeoffCheck: WBAWeightCG?

    // MARK: - Crew / passenger / cargo distribution

    /// Crew line-up (`<CrewNumber>`): cockpit and cabin crew counts.
    public var crewNumber: WBACrewNumber?

    /// Distribution of seated passengers by class (`<PaxPerClass>`).
    public var paxPerClass: [WBAClass]

    /// Cabin version — available seats by class (`<CabinVersion>`).
    public var cabinVersion: [WBAClass]

    /// Total number of passengers including non-seated (`<TotalPaxNumber>`).
    public var totalPaxNumber: Int?

    /// Passengers per cabin section (`<PaxDistribution>/<PaxPerSection>`).
    public var paxDistribution: [WBAPaxSection]

    /// Cargo weight per hold compartment (`<CargoDistribution>/<CargoPerCompartment>`).
    public var cargoDistribution: [WBACargoCompartment]

    // MARK: - Report / acknowledgement fields

    /// Load-sheet edition number (`<EditionNumber>`, AHM517).
    public var editionNumber: Int?

    /// Load-sheet agent name (`<CheckedBy>`).
    public var checkedBy: String?

    /// Balance and seating conditions label (`<BalanceSeating>`).
    public var balanceSeating: String?

    /// Last-minute changes (`<LMC>`): per-destination pax/cargo adjustments.
    public var lastMinuteChange: WBALMC?

    /// Free-text additional information for the pilot (`<AdditionalInfo>`).
    public var additionalInfo: String?

    /// Detected errors (`<WI_Error>/<Error>`), present on WIRREP error reports.
    public var errors: [WBAError]

    /// The WBA message the report refers to (`<WI_Message>`), present on WIRREP.
    public var reportedMessage: String?

    /// Unrecognized child elements preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    /// Backward-compatible initializer. All payload fields default to empty so existing
    /// `WBAMessage(header:supplementaryHeader:messageSubtype:)` call sites keep working.
    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                messageSubtype: String? = nil,
                units: WBAUnits? = nil,
                configurationCode: String? = nil,
                configuration: WBAConfiguration? = nil,
                dryOperating: WBAWeightCG? = nil,
                loading: WBALoading? = nil,
                payload: WBAPayload? = nil,
                zeroFuelCGTarget: WBAWeightCG? = nil,
                takeoffCheck: WBAWeightCG? = nil,
                crewNumber: WBACrewNumber? = nil,
                paxPerClass: [WBAClass] = [],
                cabinVersion: [WBAClass] = [],
                totalPaxNumber: Int? = nil,
                paxDistribution: [WBAPaxSection] = [],
                cargoDistribution: [WBACargoCompartment] = [],
                editionNumber: Int? = nil,
                checkedBy: String? = nil,
                balanceSeating: String? = nil,
                lastMinuteChange: WBALMC? = nil,
                additionalInfo: String? = nil,
                errors: [WBAError] = [],
                reportedMessage: String? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.messageSubtype = messageSubtype
        self.units = units
        self.configurationCode = configurationCode
        self.configuration = configuration
        self.dryOperating = dryOperating
        self.loading = loading
        self.payload = payload
        self.zeroFuelCGTarget = zeroFuelCGTarget
        self.takeoffCheck = takeoffCheck
        self.crewNumber = crewNumber
        self.paxPerClass = paxPerClass
        self.cabinVersion = cabinVersion
        self.totalPaxNumber = totalPaxNumber
        self.paxDistribution = paxDistribution
        self.cargoDistribution = cargoDistribution
        self.editionNumber = editionNumber
        self.checkedBy = checkedBy
        self.balanceSeating = balanceSeating
        self.lastMinuteChange = lastMinuteChange
        self.additionalInfo = additionalInfo
        self.errors = errors
        self.reportedMessage = reportedMessage
        self.extensions = extensions
    }
}

// MARK: - Supporting types

/// Unit context for a WBA message (`<Units>`).
public struct WBAUnits: Sendable, Equatable {
    /// Weight unit (`@weightUnit`, e.g. "kg", "lb"). All weight figures use this unit.
    public var weightUnit: String?
    /// Arm-lever (length) unit (`@armLeverUnit`, e.g. "MT" / "IN").
    public var armLeverUnit: String?
    /// Volume unit (`@volumeUnit`, e.g. "l").
    public var volumeUnit: String?

    public init(weightUnit: String? = nil, armLeverUnit: String? = nil, volumeUnit: String? = nil) {
        self.weightUnit = weightUnit
        self.armLeverUnit = armLeverUnit
        self.volumeUnit = volumeUnit
    }
}

/// A weight paired with its unit. Used wherever a WBA weight figure (`weightType`,
/// a non-negative integer) is reported; the unit is taken from the message `<Units>`.
public struct WBAWeight: Sendable, Equatable {
    /// Weight value. SAFETY-CRITICAL — interpret in `unit`.
    public var value: Int
    /// Weight unit, propagated from `<Units weightUnit>` (e.g. "kg").
    public var unit: String?

    public init(value: Int, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }
}

/// A weight + centre-of-gravity pair. Models `<DryOperating>`, `<ZF_CGTarget>`,
/// `<TO_Check>` (weight element + CG element), where CG is in 0.1% MAC.
public struct WBAWeightCG: Sendable, Equatable {
    /// Weight figure (DOW / TOW / target ZFW). SAFETY-CRITICAL.
    public var weight: WBAWeight?
    /// Centre of gravity in units of 0.1% MAC (DOCG/ZFCG/TOCG, 0...999). SAFETY-CRITICAL.
    public var centreOfGravity: Int?

    public init(weight: WBAWeight? = nil, centreOfGravity: Int? = nil) {
        self.weight = weight
        self.centreOfGravity = centreOfGravity
    }
}

/// Loading data (`<Loading>`): zero-fuel system + fuel data.
public struct WBALoading: Sendable, Equatable {
    /// Zero-fuel weight (`<ZFW>`) and zero-fuel CG (`<ZFCG>`, 0.1% MAC). SAFETY-CRITICAL.
    public var zeroFuel: WBAWeightCG?
    /// Fuel on board (`<FOB>`). SAFETY-CRITICAL.
    public var fuelOnBoard: WBAWeight?
    /// Estimated taxi fuel burnt at departure (`<TaxiFuel>`).
    public var taxiFuel: WBAWeight?
    /// Estimated trip fuel, departure→arrival (`<TripFuel>`).
    public var tripFuel: WBAWeight?
    /// Fuel density (`<FuelDensity>`, g/cm3, range 0.5...1.0).
    public var fuelDensity: Double?

    public init(zeroFuel: WBAWeightCG? = nil,
                fuelOnBoard: WBAWeight? = nil,
                taxiFuel: WBAWeight? = nil,
                tripFuel: WBAWeight? = nil,
                fuelDensity: Double? = nil) {
        self.zeroFuel = zeroFuel
        self.fuelOnBoard = fuelOnBoard
        self.taxiFuel = taxiFuel
        self.tripFuel = tripFuel
        self.fuelDensity = fuelDensity
    }
}

/// Payload data (`<Payload>`): pax and cargo weights plus total traffic weight.
public struct WBAPayload: Sendable, Equatable {
    /// Total weight of passengers and cabin bags (`<TotalPaxWeight>`). SAFETY-CRITICAL.
    public var totalPaxWeight: WBAWeight?
    /// Total weight of load in hold compartments (`<TotalCargoWeight>`). SAFETY-CRITICAL.
    public var totalCargoWeight: WBAWeight?
    /// Total traffic weight = pax + cargo (`<TotalTrafficWeight>`). SAFETY-CRITICAL.
    public var totalTrafficWeight: WBAWeight?

    public init(totalPaxWeight: WBAWeight? = nil,
                totalCargoWeight: WBAWeight? = nil,
                totalTrafficWeight: WBAWeight? = nil) {
        self.totalPaxWeight = totalPaxWeight
        self.totalCargoWeight = totalCargoWeight
        self.totalTrafficWeight = totalTrafficWeight
    }
}

/// Full aircraft W&B configuration (`<Configuration>`), present on WIFSUB.
public struct WBAConfiguration: Sendable, Equatable {
    /// Configuration code (`<ConfigurationCode>`).
    public var configurationCode: String?
    /// WBA HMI entry mode (`<EntryMode>`, e.g. "REDUCED" / "DETAILED").
    public var entryMode: String?
    /// Crew code referenced in the WBA database (`<CrewCode>`).
    public var crewCode: String?
    /// Catering code (`<Catering>/<CateringCode>`), if catering given as a code.
    public var cateringCode: String?
    /// Catering weight deviations per galley zone (`<CateringDeviationPerGalleyZone>`).
    public var cateringDeviations: [WBACateringDeviation]
    /// Loaded miscellaneous items (`<Miscellaneous>`): codes and/or ad-hoc items.
    public var miscellaneousCodes: [String]
    /// Ad-hoc miscellaneous items (`<MiscellaneousItem>`).
    public var miscellaneousItems: [WBAMiscellaneousItem]

    public init(configurationCode: String? = nil,
                entryMode: String? = nil,
                crewCode: String? = nil,
                cateringCode: String? = nil,
                cateringDeviations: [WBACateringDeviation] = [],
                miscellaneousCodes: [String] = [],
                miscellaneousItems: [WBAMiscellaneousItem] = []) {
        self.configurationCode = configurationCode
        self.entryMode = entryMode
        self.crewCode = crewCode
        self.cateringCode = cateringCode
        self.cateringDeviations = cateringDeviations
        self.miscellaneousCodes = miscellaneousCodes
        self.miscellaneousItems = miscellaneousItems
    }
}

/// A catering weight deviation for one galley zone (`<CateringDeviationPerGalleyZone>`).
public struct WBACateringDeviation: Sendable, Equatable {
    /// Galley zone identifier (`@zone`).
    public var zone: String
    /// Weight deviation (`@weight`), in the message weight unit.
    public var weight: Int?

    public init(zone: String, weight: Int? = nil) {
        self.zone = zone
        self.weight = weight
    }
}

/// An ad-hoc miscellaneous loaded item (`<MiscellaneousItem>`).
public struct WBAMiscellaneousItem: Sendable, Equatable {
    /// Item designation (`@designation`).
    public var designation: String
    /// Item weight (`@weight`), in the message weight unit.
    public var weight: Int?
    /// Horizontal arm / balance arm (`@hArm`), in the message arm-lever unit.
    public var horizontalArm: Double?

    public init(designation: String, weight: Int? = nil, horizontalArm: Double? = nil) {
        self.designation = designation
        self.weight = weight
        self.horizontalArm = horizontalArm
    }
}

/// Crew line-up (`<CrewNumber>`).
public struct WBACrewNumber: Sendable, Equatable {
    /// Number of cockpit crew members (`<CockpitCrew>`).
    public var cockpitCrew: Int?
    /// Number of cabin crew, when given as a single total (`<CabinCrew>`).
    public var cabinCrew: Int?
    /// Number of male cabin crew (`<CabinCrewMale>`).
    public var cabinCrewMale: Int?
    /// Number of female cabin crew (`<CabinCrewFemale>`).
    public var cabinCrewFemale: Int?

    public init(cockpitCrew: Int? = nil,
                cabinCrew: Int? = nil,
                cabinCrewMale: Int? = nil,
                cabinCrewFemale: Int? = nil) {
        self.cockpitCrew = cockpitCrew
        self.cabinCrew = cabinCrew
        self.cabinCrewMale = cabinCrewMale
        self.cabinCrewFemale = cabinCrewFemale
    }
}

/// A cabin class entry (`<Class>`) used by PaxPerClass / CabinVersion (distributionByClassType).
public struct WBAClass: Sendable, Equatable {
    /// Class identifier (`@classId`, e.g. "F", "C", "Y").
    public var classId: String?
    /// Number of seats in this class (`@classSeats`).
    public var seats: Int?

    public init(classId: String? = nil, seats: Int? = nil) {
        self.classId = classId
        self.seats = seats
    }
}

/// Passengers in one cabin section (`<PaxPerSection>`).
public struct WBAPaxSection: Sendable, Equatable {
    /// Section identifier (`@section`).
    public var section: String
    /// Passenger count in this section (`@sectionPaxNumber`).
    public var paxNumber: Int?
    /// Optional per-type breakdown (`<PaxPerType>`: type → count).
    public var paxPerType: [WBAPaxType]

    public init(section: String, paxNumber: Int? = nil, paxPerType: [WBAPaxType] = []) {
        self.section = section
        self.paxNumber = paxNumber
        self.paxPerType = paxPerType
    }
}

/// A passenger-type count (`<PaxPerType>`).
public struct WBAPaxType: Sendable, Equatable {
    /// Passenger type (`@PaxType`, e.g. adults/children).
    public var paxType: String?
    /// Number of passengers of this type (`@PaxNumber`).
    public var paxNumber: Int?

    public init(paxType: String? = nil, paxNumber: Int? = nil) {
        self.paxType = paxType
        self.paxNumber = paxNumber
    }
}

/// Cargo in one hold compartment (`<CargoPerCompartment>`).
public struct WBACargoCompartment: Sendable, Equatable {
    /// Compartment identifier (`@compartment`).
    public var compartment: String
    /// Cargo weight in this compartment (`@compartmentCargoWeight`), in the weight unit.
    public var weight: Int?

    public init(compartment: String, weight: Int? = nil) {
        self.compartment = compartment
        self.weight = weight
    }
}

/// Last-minute changes (`<LMC>`).
public struct WBALMC: Sendable, Equatable {
    /// Total weight of all LMC lines, signed (`@LMCTotalWeight`), in the weight unit.
    public var totalWeight: Int?
    /// Individual change lines (`<LMCLine>`).
    public var lines: [WBALMCLine]

    public init(totalWeight: Int? = nil, lines: [WBALMCLine] = []) {
        self.totalWeight = totalWeight
        self.lines = lines
    }
}

/// One last-minute change line (`<LMCLine>`): a destination plus a pax or cargo change.
public struct WBALMCLine: Sendable, Equatable {
    /// Destination airport ICAO of the change (`<LMCLineDestination>/<AirportICAOCode>`).
    public var destinationICAO: String?
    /// Destination airport IATA, if present.
    public var destinationIATA: String?
    /// Cabin section for a passenger change (`<LMCLinePax>@section`).
    public var paxSection: String?
    /// Signed passenger-count delta (`<LMCLinePax>@LMCPaxNumber`).
    public var paxNumberDelta: Int?
    /// Compartment for a cargo change (`<LMCLineCargo>@compartment`).
    public var cargoCompartment: String?
    /// Signed weight delta (`@LMCWeight`), in the message weight unit. SAFETY-CRITICAL.
    public var weightDelta: Int?

    public init(destinationICAO: String? = nil,
                destinationIATA: String? = nil,
                paxSection: String? = nil,
                paxNumberDelta: Int? = nil,
                cargoCompartment: String? = nil,
                weightDelta: Int? = nil) {
        self.destinationICAO = destinationICAO
        self.destinationIATA = destinationIATA
        self.paxSection = paxSection
        self.paxNumberDelta = paxNumberDelta
        self.cargoCompartment = cargoCompartment
        self.weightDelta = weightDelta
    }
}

/// A detected error/warning in a reported message (`<Error>`), used on WIRREP.
public struct WBAError: Sendable, Equatable {
    /// Severity category (`@category`: "WARNING" or "ERROR").
    public var category: String?
    /// Short error label (`@label`).
    public var label: String?
    /// Mixed text content of the `<Error>` element, if any.
    public var text: String?

    public init(category: String? = nil, label: String? = nil, text: String? = nil) {
        self.category = category
        self.label = label
        self.text = text
    }
}
