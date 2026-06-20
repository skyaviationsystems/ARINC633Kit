// LoadAndTrimData.swift
// ARINC633Kit
//
// Models for ARINC 633-4 LoadAndTrimData message type.
// Based on LoadAndTrimData.xsd, LTDcommon.xsd, LTDheaders.xsd schemas.

import Foundation

// MARK: - Top Level

/// Parsed LoadAndTrimData message containing weight/balance data for a flight.
public struct LoadAndTrimData: Sendable, Equatable {
    /// LTD-specific header (M633LTDHeader, not M633Header).
    public var header: ARINC633Header

    /// LTD-specific supplementary header with flight/aircraft context.
    public var supplementaryHeader: SupplementaryHeader

    /// Dry operating data (basic weight, crew, pantry, etc.).
    public var dryOperatingData: DryOperatingData?

    /// Zero fuel weight and balance data.
    public var zeroFuelData: LTDWeightData?

    /// Fuel information with per-tank breakdown.
    public var fuelInformation: LTDFuelInformation?

    /// Taxi weight and balance data.
    public var taxiData: LTDWeightData?

    /// Takeoff weight, balance, and stabilizer trim data.
    public var takeOffData: LTDTakeOffData?

    /// Landing weight and balance data.
    public var landingData: LTDWeightData?

    /// Limiting weight indicator.
    public var limitingWeight: LTDLimitingWeight?

    /// Load distribution (passengers, cargo, deadload).
    public var loadData: LTDLoadData?

    /// Author/approval information.
    public var authorName: String?
    public var authorType: String?

    /// Remarks text paragraphs.
    public var remarks: [String]

    /// Plain-text loadsheet paragraphs.
    public var loadsheetText: [String]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                dryOperatingData: DryOperatingData? = nil,
                zeroFuelData: LTDWeightData? = nil,
                fuelInformation: LTDFuelInformation? = nil,
                taxiData: LTDWeightData? = nil,
                takeOffData: LTDTakeOffData? = nil,
                landingData: LTDWeightData? = nil,
                limitingWeight: LTDLimitingWeight? = nil,
                loadData: LTDLoadData? = nil,
                authorName: String? = nil,
                authorType: String? = nil,
                remarks: [String] = [],
                loadsheetText: [String] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.dryOperatingData = dryOperatingData
        self.zeroFuelData = zeroFuelData
        self.fuelInformation = fuelInformation
        self.taxiData = taxiData
        self.takeOffData = takeOffData
        self.landingData = landingData
        self.limitingWeight = limitingWeight
        self.loadData = loadData
        self.authorName = authorName
        self.authorType = authorType
        self.remarks = remarks
        self.loadsheetText = loadsheetText
    }
}

// MARK: - Dry Operating Data

/// Dry operating weight breakdown (basic, crew, pantry, water, miscellaneous).
public struct DryOperatingData: Sendable, Equatable {
    /// Basic aircraft weight.
    public var basicWeight: ARINCWeight?
    /// Basic index value.
    public var basicIndex: Double?

    /// Crew weight and index.
    public var crewWeight: ARINCWeight?
    public var crewIndex: Double?

    /// Pantry weight and index.
    public var pantryWeight: ARINCWeight?
    public var pantryIndex: Double?

    /// Potable water weight and index.
    public var potableWaterWeight: ARINCWeight?
    public var potableWaterIndex: Double?

    /// Miscellaneous data items (baggage, ballast, etc.).
    public var miscellaneousItems: [LTDMiscellaneousItem]

    /// Pantry code.
    public var pantryCode: String?

    /// Crew complement.
    public var crewComplement: LTDCrewComplement?

    /// Total DOW weight.
    public var totalWeight: ARINCWeight?
    /// Total DOW index.
    public var dryOperatingIndex: Double?

    public init(basicWeight: ARINCWeight? = nil, basicIndex: Double? = nil,
                crewWeight: ARINCWeight? = nil, crewIndex: Double? = nil,
                pantryWeight: ARINCWeight? = nil, pantryIndex: Double? = nil,
                potableWaterWeight: ARINCWeight? = nil, potableWaterIndex: Double? = nil,
                miscellaneousItems: [LTDMiscellaneousItem] = [],
                pantryCode: String? = nil, crewComplement: LTDCrewComplement? = nil,
                totalWeight: ARINCWeight? = nil, dryOperatingIndex: Double? = nil) {
        self.basicWeight = basicWeight
        self.basicIndex = basicIndex
        self.crewWeight = crewWeight
        self.crewIndex = crewIndex
        self.pantryWeight = pantryWeight
        self.pantryIndex = pantryIndex
        self.potableWaterWeight = potableWaterWeight
        self.potableWaterIndex = potableWaterIndex
        self.miscellaneousItems = miscellaneousItems
        self.pantryCode = pantryCode
        self.crewComplement = crewComplement
        self.totalWeight = totalWeight
        self.dryOperatingIndex = dryOperatingIndex
    }
}

/// Miscellaneous weight item within dry operating data.
public struct LTDMiscellaneousItem: Sendable, Equatable {
    public var description: String?
    public var weight: ARINCWeight?
    public var index: Double?
    public var location: String?

    public init(description: String? = nil, weight: ARINCWeight? = nil,
                index: Double? = nil, location: String? = nil) {
        self.description = description
        self.weight = weight
        self.index = index
        self.location = location
    }
}

/// Crew complement (cockpit and cabin by gender).
public struct LTDCrewComplement: Sendable, Equatable {
    public var cockpitMale: Int?
    public var cockpitFemale: Int?
    public var cabinMale: Int?
    public var cabinFemale: Int?

    public init(cockpitMale: Int? = nil, cockpitFemale: Int? = nil,
                cabinMale: Int? = nil, cabinFemale: Int? = nil) {
        self.cockpitMale = cockpitMale
        self.cockpitFemale = cockpitFemale
        self.cabinMale = cabinMale
        self.cabinFemale = cabinFemale
    }
}

// MARK: - Weight Data

/// Weight/balance data section (used for ZFW, taxi, landing).
public struct LTDWeightData: Sendable, Equatable {
    /// Weight value.
    public var weight: ARINCWeight?
    /// Maximum weight limit.
    public var maxWeight: ARINCWeight?

    /// Index value (e.g., ZeroFuelIndex, TaxiIndex).
    public var index: Double?
    /// Index aft limit.
    public var indexAftLimit: Double?
    /// Index forward limit.
    public var indexForwardLimit: Double?

    /// MAC percentage.
    public var mac: Double?
    /// MAC aft limit.
    public var macAftLimit: Double?
    /// MAC forward limit.
    public var macForwardLimit: Double?

    /// Taxi-specific: maximum ramp weight limit.
    public var rampWeightLimit: ARINCWeight?

    public init(weight: ARINCWeight? = nil, maxWeight: ARINCWeight? = nil,
                index: Double? = nil, indexAftLimit: Double? = nil,
                indexForwardLimit: Double? = nil, mac: Double? = nil,
                macAftLimit: Double? = nil, macForwardLimit: Double? = nil,
                rampWeightLimit: ARINCWeight? = nil) {
        self.weight = weight
        self.maxWeight = maxWeight
        self.index = index
        self.indexAftLimit = indexAftLimit
        self.indexForwardLimit = indexForwardLimit
        self.mac = mac
        self.macAftLimit = macAftLimit
        self.macForwardLimit = macForwardLimit
        self.rampWeightLimit = rampWeightLimit
    }
}

// MARK: - Takeoff Data

/// Takeoff weight/balance with stabilizer settings.
public struct LTDTakeOffData: Sendable, Equatable {
    /// Takeoff weight and balance.
    public var weightData: LTDWeightData

    /// Stabilizer trim settings.
    public var stabSettings: [LTDStabSetting]

    public init(weightData: LTDWeightData = LTDWeightData(),
                stabSettings: [LTDStabSetting] = []) {
        self.weightData = weightData
        self.stabSettings = stabSettings
    }
}

/// Stabilizer trim setting.
public struct LTDStabSetting: Sendable, Equatable {
    /// Trim value.
    public var value: Double?
    /// Nose up or down.
    public var noseUpDown: String?
    /// Takeoff configuration description.
    public var takeOffConfiguration: String?

    public init(value: Double? = nil, noseUpDown: String? = nil,
                takeOffConfiguration: String? = nil) {
        self.value = value
        self.noseUpDown = noseUpDown
        self.takeOffConfiguration = takeOffConfiguration
    }
}

// MARK: - Fuel Information

/// Fuel information with density and per-condition fuel entries.
public struct LTDFuelInformation: Sendable, Equatable {
    /// Fuel density.
    public var density: ARINCDensity?
    /// Fuel entries by condition (block, takeoff, trip, landing, taxi).
    public var fuelEntries: [LTDFuelEntry]

    public init(density: ARINCDensity? = nil, fuelEntries: [LTDFuelEntry] = []) {
        self.density = density
        self.fuelEntries = fuelEntries
    }
}

/// Fuel entry for a specific fuel condition.
public struct LTDFuelEntry: Sendable, Equatable {
    /// Fuel condition (BlockFuel, TakeoffFuel, TripFuel, LandingFuel, TaxiFuel).
    public var condition: String
    /// Total fuel weight.
    public var totalWeight: ARINCWeight?
    /// Total fuel location.
    public var totalLocation: String?
    /// Tank volume limit.
    public var totalTankVolume: ARINCVolume?
    /// Individual tank breakdowns.
    public var tanks: [LTDFuelTank]

    public init(condition: String = "", totalWeight: ARINCWeight? = nil,
                totalLocation: String? = nil, totalTankVolume: ARINCVolume? = nil,
                tanks: [LTDFuelTank] = []) {
        self.condition = condition
        self.totalWeight = totalWeight
        self.totalLocation = totalLocation
        self.totalTankVolume = totalTankVolume
        self.tanks = tanks
    }
}

/// Individual fuel tank data.
public struct LTDFuelTank: Sendable, Equatable {
    /// Tank fuel weight.
    public var weight: ARINCWeight?
    /// Tank location name.
    public var location: String?
    /// Tank volume limit.
    public var tankVolume: ARINCVolume?

    public init(weight: ARINCWeight? = nil, location: String? = nil,
                tankVolume: ARINCVolume? = nil) {
        self.weight = weight
        self.location = location
        self.tankVolume = tankVolume
    }
}

// MARK: - Limiting Weight

/// Indicator of which weight is limiting.
public struct LTDLimitingWeight: Sendable, Equatable {
    public var isZeroFuelWeight: Bool
    public var isTakeOffWeight: Bool
    public var isLandingWeight: Bool

    public init(isZeroFuelWeight: Bool = false,
                isTakeOffWeight: Bool = false,
                isLandingWeight: Bool = false) {
        self.isZeroFuelWeight = isZeroFuelWeight
        self.isTakeOffWeight = isTakeOffWeight
        self.isLandingWeight = isLandingWeight
    }
}

// MARK: - Load Data

/// Load distribution data (passengers and cargo).
public struct LTDLoadData: Sendable, Equatable {
    /// Cabin version name.
    public var cabinVersionName: String?
    /// Cabin class definitions.
    public var cabinClasses: [LTDCabinClass]
    /// Passenger count per class.
    public var paxPerClass: [LTDCabinClass]
    /// Passenger distribution type.
    public var passengerTrimType: String?
    /// Passenger sections.
    public var cabinSections: [LTDCabinSection]
    /// Total passenger count.
    public var totalPax: Int?
    /// Passenger breakdown by type (adult, child, infant).
    public var paxByType: [LTDPaxGender]
    /// Total passenger weight.
    public var totalPaxWeight: ARINCWeight?
    /// Deadload (cargo) per compartment.
    public var deadloadCompartments: [LTDDeadloadCompartment]
    /// Total deadload weight and index.
    public var totalDeadloadWeight: ARINCWeight?
    public var totalDeadloadIndex: Double?
    /// Traffic load (total payload).
    public var trafficLoadWeight: ARINCWeight?
    /// Underload (remaining capacity).
    public var underload: ARINCWeight?
    /// Lateral imbalance.
    public var lateralImbalanceRight: ARINCWeight?
    public var lateralImbalanceLeft: ARINCWeight?

    public init(cabinVersionName: String? = nil, cabinClasses: [LTDCabinClass] = [],
                paxPerClass: [LTDCabinClass] = [], passengerTrimType: String? = nil,
                cabinSections: [LTDCabinSection] = [], totalPax: Int? = nil,
                paxByType: [LTDPaxGender] = [], totalPaxWeight: ARINCWeight? = nil,
                deadloadCompartments: [LTDDeadloadCompartment] = [],
                totalDeadloadWeight: ARINCWeight? = nil, totalDeadloadIndex: Double? = nil,
                trafficLoadWeight: ARINCWeight? = nil, underload: ARINCWeight? = nil,
                lateralImbalanceRight: ARINCWeight? = nil, lateralImbalanceLeft: ARINCWeight? = nil) {
        self.cabinVersionName = cabinVersionName
        self.cabinClasses = cabinClasses
        self.paxPerClass = paxPerClass
        self.passengerTrimType = passengerTrimType
        self.cabinSections = cabinSections
        self.totalPax = totalPax
        self.paxByType = paxByType
        self.totalPaxWeight = totalPaxWeight
        self.deadloadCompartments = deadloadCompartments
        self.totalDeadloadWeight = totalDeadloadWeight
        self.totalDeadloadIndex = totalDeadloadIndex
        self.trafficLoadWeight = trafficLoadWeight
        self.underload = underload
        self.lateralImbalanceRight = lateralImbalanceRight
        self.lateralImbalanceLeft = lateralImbalanceLeft
    }
}

/// Cabin class definition.
public struct LTDCabinClass: Sendable, Equatable {
    public var classId: String
    public var seats: Int?
    public var blockedSeats: Int?

    public init(classId: String = "", seats: Int? = nil, blockedSeats: Int? = nil) {
        self.classId = classId
        self.seats = seats
        self.blockedSeats = blockedSeats
    }
}

/// Cabin section with passenger count.
public struct LTDCabinSection: Sendable, Equatable {
    public var section: String
    public var paxCount: Int

    public init(section: String = "", paxCount: Int = 0) {
        self.section = section
        self.paxCount = paxCount
    }
}

/// Passenger breakdown by type/gender.
public struct LTDPaxGender: Sendable, Equatable {
    public var paxType: String
    public var count: Int
    public var weight: ARINCWeight?

    public init(paxType: String = "", count: Int = 0, weight: ARINCWeight? = nil) {
        self.paxType = paxType
        self.count = count
        self.weight = weight
    }
}

/// Deadload (cargo) per compartment.
public struct LTDDeadloadCompartment: Sendable, Equatable {
    public var location: String?
    public var weight: ARINCWeight?
    public var index: Double?
    public var isTransit: Bool?

    public init(location: String? = nil, weight: ARINCWeight? = nil,
                index: Double? = nil, isTransit: Bool? = nil) {
        self.location = location
        self.weight = weight
        self.index = index
        self.isTransit = isTransit
    }
}
