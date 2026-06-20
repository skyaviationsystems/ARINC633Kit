// LoadAndTrimDataParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633-4 LoadAndTrimData message type.
// Uses M633LTDHeader (not M633Header) per spec -- see Research Pitfall 5.

import Foundation

// MARK: - LTD Section State Machine

/// Section context for LoadAndTrimData parsing.
private enum LTDSection {
    case none
    case dryOperatingData
    case basicData
    case crewData
    case pantryData
    case potableWaterData
    case miscellaneousData
    case crewComplement
    case zeroFuelData
    case fuelInformation
    case taxiData
    case takeOffData
    case landingData
    case limitingWeight
    case loadData
    case loadDistribution
    case cabinVersion
    case paxPerClass
    case paxDistribution
    case paxPerSection
    case totalPaxNumber
    case deadloadDistribution
    case totalDeadload
    case trafficLoad
    case authorInformation
    case remarks
    case loadsheetText
}

/// SAX parser for ARINC 633-4 LoadAndTrimData message type.
final class LoadAndTrimDataParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = LoadAndTrimData()

    // MARK: - Section State Machine

    private var currentSection: LTDSection = .none

    // MARK: - Builder State

    private var currentFuelCondition: String = ""
    private var currentFuelEntry = LTDFuelEntry()
    private var currentFuelTank = LTDFuelTank()
    private var inIndividualTank = false
    private var inTotalFuel = false

    private var currentMiscItem = LTDMiscellaneousItem()
    private var currentDeadloadCompartment = LTDDeadloadCompartment()
    private var currentStabSetting = LTDStabSetting()

    // Temporary header builders
    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var suppFlightAirlineCode = ""
    private var suppFlightNumber = ""
    private var suppFlightIdentifier: String?
    private var suppCommercialFlightNumber: String?
    private var suppDepartureICAO = ""
    private var suppDepartureIATA: String?
    private var suppArrivalICAO = ""
    private var suppArrivalIATA: String?
    private var suppFlightOriginDate: String?
    private var suppScheduledDeparture: String?
    private var suppAircraftRegistration = ""
    private var suppAircraftType: String?
    private var suppAircraftSubType: String?

    private var inDepartureAirport = false
    private var inArrivalAirport = false

    // MARK: - Public Interface

    /// Parse LoadAndTrimData XML data.
    func parse(data: Data) throws -> LoadAndTrimData {
        try run(data: data)
        finalizeHeaders()
        return result
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "M633LTDHeader":
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""

        case "Flight":
            suppFlightOriginDate = attributes["flightOriginDate"]
            suppScheduledDeparture = attributes["scheduledTimeOfDeparture"]

        case "FlightNumber":
            suppFlightAirlineCode = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
            suppFlightNumber = attributes["number"] ?? ""

        case "DepartureAirport":
            inDepartureAirport = true
            inArrivalAirport = false

        case "ArrivalAirport":
            inArrivalAirport = true
            inDepartureAirport = false

        case "Aircraft":
            suppAircraftRegistration = attributes["aircraftRegistration"] ?? ""

        case "AircraftModel":
            suppAircraftSubType = attributes["airlineSpecificSubType"]

        // Section transitions
        case "DryOperatingData":
            currentSection = .dryOperatingData
            if result.dryOperatingData == nil {
                result.dryOperatingData = DryOperatingData()
            }

        case "BasicData":
            if currentSection == .dryOperatingData {
                currentSection = .basicData
            }

        case "CrewData":
            if currentSection == .dryOperatingData || currentSection == .basicData {
                currentSection = .crewData
            }

        case "PantryData":
            if currentSection == .dryOperatingData || currentSection == .basicData || currentSection == .crewData {
                currentSection = .pantryData
            }

        case "PotableWaterData":
            currentSection = .potableWaterData

        case "MiscellaneousData":
            currentSection = .miscellaneousData
            currentMiscItem = LTDMiscellaneousItem()
            currentMiscItem.description = attributes["description"]

        case "CrewComplement":
            currentSection = .crewComplement
            if result.dryOperatingData?.crewComplement == nil {
                result.dryOperatingData?.crewComplement = LTDCrewComplement()
            }

        case "ZeroFuelData":
            currentSection = .zeroFuelData
            if result.zeroFuelData == nil {
                result.zeroFuelData = LTDWeightData()
            }

        case "FuelInformation":
            currentSection = .fuelInformation
            if result.fuelInformation == nil {
                result.fuelInformation = LTDFuelInformation()
            }

        case "Fuel":
            currentFuelCondition = attributes["fuelCondition"] ?? ""
            currentFuelEntry = LTDFuelEntry(condition: currentFuelCondition)

        case "Total":
            if currentSection == .fuelInformation {
                inTotalFuel = true
                inIndividualTank = false
            }

        case "Individual":
            if currentSection == .fuelInformation {
                inIndividualTank = true
                inTotalFuel = false
                currentFuelTank = LTDFuelTank()
            }

        case "TaxiData":
            currentSection = .taxiData
            if result.taxiData == nil {
                result.taxiData = LTDWeightData()
            }

        case "TakeOffData":
            currentSection = .takeOffData
            if result.takeOffData == nil {
                result.takeOffData = LTDTakeOffData()
            }

        case "StabTrimUnit":
            currentStabSetting = LTDStabSetting()
            currentStabSetting.noseUpDown = attributes["noseUpDown"]
            currentStabSetting.takeOffConfiguration = attributes["takeOffConfiguration"]

        case "LandingData":
            currentSection = .landingData
            if result.landingData == nil {
                result.landingData = LTDWeightData()
            }

        case "LimitingWeight":
            currentSection = .limitingWeight
            if result.limitingWeight == nil {
                result.limitingWeight = LTDLimitingWeight()
            }

        case "LoadData":
            currentSection = .loadData
            if result.loadData == nil {
                result.loadData = LTDLoadData()
            }

        case "LoadDistribution":
            currentSection = .loadDistribution

        case "LTDCabinVersion":
            currentSection = .cabinVersion
            result.loadData?.cabinVersionName = attributes["cabinVersionName"]

        case "LTDPaxPerClass":
            currentSection = .paxPerClass

        case "LTDPaxDistribution":
            currentSection = .paxDistribution
            result.loadData?.passengerTrimType = attributes["passengerTrimType"]

        case "PaxPerSection":
            currentSection = .paxPerSection

        case "CabinSection":
            if currentSection == .paxPerSection {
                let section = attributes["cabinSection"] ?? ""
                let count = Int(attributes["paxCount"] ?? "") ?? 0
                result.loadData?.cabinSections.append(LTDCabinSection(section: section, paxCount: count))
            }

        case "LTDTotalPaxNumber":
            currentSection = .totalPaxNumber
            result.loadData?.totalPax = Int(attributes["totalPax"] ?? "")

        case "PaxPerGender":
            let paxType = attributes["paxType"] ?? ""
            let count = Int(attributes["paxCount"] ?? "") ?? 0
            let weight: ARINCWeight? = {
                if let w = attributes["weight"], let v = Double(w) {
                    return ARINCWeight(value: v, unit: "kg")
                }
                return nil
            }()
            result.loadData?.paxByType.append(LTDPaxGender(paxType: paxType, count: count, weight: weight))

        case "DeadloadDistribution":
            currentSection = .deadloadDistribution

        case "DeadloadPerCompartment":
            currentDeadloadCompartment = LTDDeadloadCompartment()
            if let transit = attributes["transit"] {
                currentDeadloadCompartment.isTransit = (transit == "true")
            }

        case "TotalDeadload":
            currentSection = .totalDeadload

        case "TrafficLoad":
            currentSection = .trafficLoad

        case "AuthorInformation":
            currentSection = .authorInformation

        case "AuthorName":
            if currentSection == .authorInformation {
                result.authorType = attributes["authorType"]
            }

        case "Remarks":
            if !stackContains("LoadAndTrimDataText") {
                currentSection = .remarks
            }

        case "LoadAndTrimDataText":
            currentSection = .loadsheetText

        case "Class":
            if currentSection == .cabinVersion {
                let classId = attributes["classId"] ?? ""
                let seats = Int(attributes["classSeats"] ?? "")
                let blocked = Int(attributes["blockedSeats"] ?? "")
                result.loadData?.cabinClasses.append(LTDCabinClass(classId: classId, seats: seats, blockedSeats: blocked))
            } else if currentSection == .paxPerClass {
                let classId = attributes["classId"] ?? ""
                let seats = Int(attributes["classSeats"] ?? "")
                result.loadData?.paxPerClass.append(LTDCabinClass(classId: classId, seats: seats))
            }

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        // Supplementary header elements
        case "FlightIdentifier":
            suppFlightIdentifier = text

        case "CommercialFlightNumber":
            if stackContains("M633LTDSupplementaryHeader") {
                suppCommercialFlightNumber = text
            }

        case "AirportICAOCode":
            if inDepartureAirport { suppDepartureICAO = text }
            else if inArrivalAirport { suppArrivalICAO = text }

        case "AirportIATACode":
            if inDepartureAirport { suppDepartureIATA = text }
            else if inArrivalAirport { suppArrivalIATA = text }

        case "AircraftICAOType", "AircraftIATAType":
            suppAircraftType = text

        case "DepartureAirport":
            inDepartureAirport = false

        case "ArrivalAirport":
            inArrivalAirport = false

        // Value element -- context-dependent
        case "Value":
            handleValue(text)

        // Balance/index elements
        case "BasicIndex":
            if currentSection == .basicData {
                result.dryOperatingData?.basicIndex = Double(text)
            }

        case "Index":
            handleIndex(text)

        case "DryOperatingIndex":
            result.dryOperatingData?.dryOperatingIndex = Double(text)

        case "ZeroFuelIndex":
            result.zeroFuelData?.index = Double(text)
            result.zeroFuelData?.indexAftLimit = Double(currentAttributes["aftLimit"] ?? "")
            result.zeroFuelData?.indexForwardLimit = Double(currentAttributes["forwardLimit"] ?? "")

        case "MACZeroFuel":
            result.zeroFuelData?.mac = Double(text)
            result.zeroFuelData?.macAftLimit = Double(currentAttributes["aftLimit"] ?? "")
            result.zeroFuelData?.macForwardLimit = Double(currentAttributes["forwardLimit"] ?? "")

        case "TaxiIndex":
            result.taxiData?.index = Double(text)

        case "MACTaxi":
            result.taxiData?.mac = Double(text)

        case "TakeOffIndex":
            result.takeOffData?.weightData.index = Double(text)
            result.takeOffData?.weightData.indexAftLimit = Double(currentAttributes["aftLimit"] ?? "")
            result.takeOffData?.weightData.indexForwardLimit = Double(currentAttributes["forwardLimit"] ?? "")

        case "MACTakeOff":
            result.takeOffData?.weightData.mac = Double(text)
            result.takeOffData?.weightData.macAftLimit = Double(currentAttributes["aftLimit"] ?? "")
            result.takeOffData?.weightData.macForwardLimit = Double(currentAttributes["forwardLimit"] ?? "")

        case "LandingIndex":
            result.landingData?.index = Double(text)

        case "MACLanding":
            result.landingData?.mac = Double(text)

        case "StabTrimUnit":
            currentStabSetting.value = Double(text)
            result.takeOffData?.stabSettings.append(currentStabSetting)

        case "PantryCode":
            result.dryOperatingData?.pantryCode = text

        case "Location":
            handleLocation(text)

        // Crew complement
        case "Male":
            if currentSection == .crewComplement {
                if parent == "Cockpit" {
                    result.dryOperatingData?.crewComplement?.cockpitMale = Int(text)
                } else if parent == "Cabin" {
                    result.dryOperatingData?.crewComplement?.cabinMale = Int(text)
                }
            }

        case "Female":
            if currentSection == .crewComplement {
                if parent == "Cockpit" {
                    result.dryOperatingData?.crewComplement?.cockpitFemale = Int(text)
                } else if parent == "Cabin" {
                    result.dryOperatingData?.crewComplement?.cabinFemale = Int(text)
                }
            }

        // Fuel
        case "Fuel":
            currentFuelEntry.condition = currentFuelCondition
            result.fuelInformation?.fuelEntries.append(currentFuelEntry)
            currentFuelEntry = LTDFuelEntry()
            currentFuelCondition = ""

        case "Total":
            inTotalFuel = false

        case "Individual":
            if currentSection == .fuelInformation {
                currentFuelEntry.tanks.append(currentFuelTank)
                currentFuelTank = LTDFuelTank()
                inIndividualTank = false
            }

        // Limiting weight
        case "ZeroFuelWeight":
            if currentSection == .limitingWeight {
                result.limitingWeight?.isZeroFuelWeight = (text.lowercased() == "true")
            }

        case "TakeOffWeight":
            if currentSection == .limitingWeight {
                result.limitingWeight?.isTakeOffWeight = (text.lowercased() == "true")
            }

        case "LandingWeight":
            if currentSection == .limitingWeight {
                result.limitingWeight?.isLandingWeight = (text.lowercased() == "true")
            }

        // Deadload
        case "DeadloadPerCompartment":
            result.loadData?.deadloadCompartments.append(currentDeadloadCompartment)
            currentDeadloadCompartment = LTDDeadloadCompartment()

        // Author
        case "AuthorName":
            if currentSection == .authorInformation {
                result.authorName = text
            }

        // Loadsheet text
        case "Text":
            if currentSection == .loadsheetText {
                result.loadsheetText.append(text)
            } else if currentSection == .remarks {
                result.remarks.append(text)
            }

        // Section closes
        case "DryOperatingData":
            currentSection = .none
        case "BasicData":
            currentSection = .dryOperatingData
        case "CrewData":
            currentSection = .dryOperatingData
        case "PantryData":
            currentSection = .dryOperatingData
        case "PotableWaterData":
            currentSection = .dryOperatingData
        case "MiscellaneousData":
            result.dryOperatingData?.miscellaneousItems.append(currentMiscItem)
            currentSection = .dryOperatingData
        case "CrewComplement":
            currentSection = .dryOperatingData
        case "ZeroFuelData":
            currentSection = .none
        case "FuelInformation":
            currentSection = .none
        case "TaxiData":
            currentSection = .none
        case "TakeOffData":
            currentSection = .none
        case "LandingData":
            currentSection = .none
        case "LimitingWeight":
            currentSection = .none
        case "LoadData":
            currentSection = .none
        case "LoadDistribution":
            currentSection = .loadData
        case "LTDCabinVersion":
            currentSection = .loadDistribution
        case "LTDPaxPerClass":
            currentSection = .loadDistribution
        case "LTDPaxDistribution":
            currentSection = .loadDistribution
        case "PaxPerSection":
            currentSection = .paxDistribution
        case "LTDTotalPaxNumber":
            currentSection = .loadDistribution
        case "DeadloadDistribution":
            currentSection = .loadDistribution
        case "TotalDeadload":
            currentSection = .loadDistribution
        case "TrafficLoad":
            currentSection = .loadData
        case "AuthorInformation":
            currentSection = .none
        case "Remarks":
            if currentSection == .remarks {
                currentSection = .none
            }
        case "LoadAndTrimDataText":
            currentSection = .none

        default:
            break
        }
    }

    // MARK: - Value Handling

    private func handleValue(_ text: String) {
        let unit = currentAttributes["unit"] ?? ""
        guard let numericValue = Double(text) else { return }

        switch currentSection {
        case .basicData:
            if stackContains("Weight") {
                result.dryOperatingData?.basicWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .crewData:
            if stackContains("Weight") {
                result.dryOperatingData?.crewWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .pantryData:
            if stackContains("Weight") {
                result.dryOperatingData?.pantryWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .potableWaterData:
            if stackContains("Weight") {
                result.dryOperatingData?.potableWaterWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .miscellaneousData:
            if stackContains("Weight") {
                currentMiscItem.weight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .dryOperatingData:
            // DOW total weight
            if stackContains("Weight") && !stackContains("DryOperatingBreakdown") {
                result.dryOperatingData?.totalWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .zeroFuelData:
            if stackContains("Limits") || stackContains("Maximum") {
                result.zeroFuelData?.maxWeight = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Weight") {
                result.zeroFuelData?.weight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .fuelInformation:
            if stackContains("Density") && !stackContains("Fuel") {
                result.fuelInformation?.density = ARINCDensity(value: numericValue, unit: unit)
            } else if stackContains("TankVolume") {
                if inIndividualTank {
                    currentFuelTank.tankVolume = ARINCVolume(value: numericValue, unit: unit)
                } else if inTotalFuel {
                    currentFuelEntry.totalTankVolume = ARINCVolume(value: numericValue, unit: unit)
                }
            } else if stackContains("Weight") {
                if inIndividualTank {
                    currentFuelTank.weight = ARINCWeight(value: numericValue, unit: unit)
                } else if inTotalFuel {
                    currentFuelEntry.totalWeight = ARINCWeight(value: numericValue, unit: unit)
                }
            }

        case .taxiData:
            if stackContains("Limit") && !stackContains("Limits") {
                result.taxiData?.rampWeightLimit = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Weight") {
                result.taxiData?.weight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .takeOffData:
            if stackContains("Limits") || stackContains("Maximum") {
                result.takeOffData?.weightData.maxWeight = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Weight") {
                result.takeOffData?.weightData.weight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .landingData:
            if stackContains("Limits") || stackContains("Maximum") {
                result.landingData?.maxWeight = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Weight") {
                result.landingData?.weight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .totalPaxNumber:
            // LTDTotalPaxWeight
            if stackContains("LTDTotalPaxWeight") {
                result.loadData?.totalPaxWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .loadDistribution:
            if stackContains("LTDTotalPaxWeight") {
                result.loadData?.totalPaxWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .deadloadDistribution:
            if stackContains("Weight") {
                currentDeadloadCompartment.weight = ARINCWeight(value: numericValue, unit: unit.isEmpty ? "kg" : unit)
            }

        case .totalDeadload:
            if stackContains("Weight") {
                result.loadData?.totalDeadloadWeight = ARINCWeight(value: numericValue, unit: unit.isEmpty ? "kg" : unit)
            }

        case .trafficLoad:
            if stackContains("Weight") {
                result.loadData?.trafficLoadWeight = ARINCWeight(value: numericValue, unit: unit)
            }

        case .loadData:
            if stackContains("Underload") {
                result.loadData?.underload = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Right") {
                result.loadData?.lateralImbalanceRight = ARINCWeight(value: numericValue, unit: unit)
            } else if stackContains("Left") {
                result.loadData?.lateralImbalanceLeft = ARINCWeight(value: numericValue, unit: unit)
            }

        default:
            break
        }
    }

    // MARK: - Index Handling

    private func handleIndex(_ text: String) {
        guard let val = Double(text) else { return }

        switch currentSection {
        case .crewData:
            result.dryOperatingData?.crewIndex = val
        case .pantryData:
            result.dryOperatingData?.pantryIndex = val
        case .potableWaterData:
            result.dryOperatingData?.potableWaterIndex = val
        case .miscellaneousData:
            currentMiscItem.index = val
        case .deadloadDistribution:
            currentDeadloadCompartment.index = val
        case .totalDeadload:
            result.loadData?.totalDeadloadIndex = val
        default:
            break
        }
    }

    // MARK: - Location Handling

    private func handleLocation(_ text: String) {
        switch currentSection {
        case .fuelInformation:
            if inIndividualTank {
                currentFuelTank.location = text
            } else if inTotalFuel {
                currentFuelEntry.totalLocation = text
            }
        case .miscellaneousData:
            currentMiscItem.location = text
        case .deadloadDistribution:
            currentDeadloadCompartment.location = text
        default:
            break
        }
    }

    // MARK: - Finalize

    private func finalizeHeaders() {
        result.header = ARINC633Header(
            versionNumber: headerVersionNumber,
            timestamp: headerTimestamp
        )
        result.supplementaryHeader = SupplementaryHeader(
            flight: ARINCHeaderFlight(
                airlineCode: suppFlightAirlineCode,
                flightNumber: suppFlightNumber,
                flightIdentifier: suppFlightIdentifier,
                commercialFlightNumber: suppCommercialFlightNumber,
                departure: ARINCHeaderAirport(
                    icaoCode: suppDepartureICAO,
                    iataCode: suppDepartureIATA
                ),
                arrival: ARINCHeaderAirport(
                    icaoCode: suppArrivalICAO,
                    iataCode: suppArrivalIATA
                ),
                scheduledDepartureTime: suppScheduledDeparture,
                flightOriginDate: suppFlightOriginDate
            ),
            aircraft: ARINCHeaderAircraft(
                registration: suppAircraftRegistration,
                aircraftType: suppAircraftType,
                engineType: suppAircraftSubType
            )
        )
    }
}
