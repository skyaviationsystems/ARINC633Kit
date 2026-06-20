// FlightPlanParser.swift
// ARINC633Kit
//
// Full 13-section FlightPlan SAX parser using section-context state machine.
// Handles Atlas Air versionNumber="3", altitude in ft/100, rich fuel categories,
// contingency saving headers with separate route data, and all ARINC 633-4 sections.

import Foundation

/// Section-context state machine for FlightPlan parsing.
///
/// Tracks which major section the parser is currently inside, enabling
/// correct disambiguation of reused element names like <Value>.
enum FlightPlanSection {
    case none
    case flightInfo
    case remarks
    case flightPlanHeader
    case fuelHeader
    case weightHeader
    case waypoints
    case summary
    case etopsSummary
    case alternateRoutes
    case airportDataList
    case contingencySaving
    case contingencySavingFuelHeader
    case contingencySavingWaypoints
    case fuelStatistics
    case tankeringInfo
    case terrainClearance
}

/// SAX parser for ARINC 633-4 FlightPlan message type.
///
/// Uses a section-context state machine layered on top of SAXParserEngine's
/// element stack to correctly disambiguate <Value> elements.
final class FlightPlanParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var flightPlan = FlightPlan()

    // MARK: - Section State Machine

    private var currentSection: FlightPlanSection = .none

    // MARK: - Builder State

    // Fuel context tracking
    private var currentFuelContext: String = ""
    private var currentAlternateFuel = AlternateFuelEntry()
    private var inAlternateFuel = false
    private var inFinalReserve = false
    private var currentAdditionalReason: String = ""
    private var currentExtraReason: String = ""
    private var inAdditionalFuel = false
    private var inExtraFuel = false
    private var additionalWeight: ARINCWeight?
    private var additionalDuration: ARINC633Duration?
    private var extraWeight: ARINCWeight?
    private var extraDuration: ARINC633Duration?

    // Weight context tracking
    private var currentWeightContext: String = ""

    // Waypoint builder
    private var currentWaypoint: Waypoint?
    private var inWaypoint = false

    // Track type attribute for Value elements
    private var currentValueUnit: String = ""
    private var currentValueType: String = ""

    // Wind builder within waypoint
    private var windDirection: Double?
    private var windSpeed: ARINCSpeed?

    // MEL/CDL builder
    private var currentMELType: String = ""
    private var currentMELRefId: String = ""
    private var currentMELTitle: String = ""
    private var currentMELHandled: Bool = false
    private var currentMELEffects: [MELEffect] = []
    private var inMELEffects = false
    private var currentEffectIdentifier: String = ""
    private var currentEffectValue: String?
    private var currentEffectDescription: String = ""
    private var inEffect = false
    private var melRemarkBuffer: String = ""
    private var inMELRemarks = false

    // Alternate route builder
    private var currentAlternateRoute: AlternateRoute?
    private var inAlternateRouteWaypoints = false

    // Airport data builder
    private var currentAirportData: AirportData?

    // ContingencySaving builders
    private var contingencySaving = ContingencySaving()
    private var contingencyFuelHeader = FuelHeader()
    private var contingencyFuelContext: String = ""
    private var contingencyAlternateFuel = AlternateFuelEntry()
    private var inContingencyAlternateFuel = false
    private var inContingencyFinalReserve = false

    // ETOPS builder
    private var currentCriticalPosition: CriticalPosition?
    private var currentSuitableAirport: ETOPSSuitableAirport?
    private var currentAdequateAirport: AdequateAirport?
    private var inCriticalPositions = false
    private var inSuitableAirport = false
    private var inAdequateAirport = false
    private var inTerrainAvoidance = false
    private var etopsSuitableAirportParent: String = ""
    // Safe altitude builder (used inside both SuitableAirport and AdequateAirport terrain avoidance)
    private var currentSafeAltitudeValue: ARINCAltitude?
    private var currentSafeAltitudeDistance: ARINCDistance?
    private var inSafeAltitude = false

    // CrewList builder (633-5 embedded crew in FlightInfo)
    private var inCrewList = false

    // CostInformation builder (633-5)
    private var inCostInformation = false
    private var costCurrency: String = ""
    private var costTotal: Double?
    private var costFuel: Double?
    private var costTime: Double?
    private var costDelay: Double?
    private var costEnroute: Double?
    private var costOtherQualifier: String = ""
    private var costOthers: [OtherCost] = []

    // EnvironmentalImpactFactors builder (633-5)
    private var inEnvironmentalImpact = false
    private var envCO2: Double?
    private var envEF: Double?

    // InformationalFuel builder
    private var inInformationalFuel = false
    private var informationalReason: String = ""
    private var informationalLabel: String?
    private var informationalWeight: ARINCWeight?
    private var informationalDuration: ARINC633Duration?

    // MinimumBlockFuel / MinimumTakeOffFuel context
    private var inMinimumBlockFuel = false
    private var inMinimumTakeOffFuel = false
    private var inLandingFuel = false

    // Airspace traversal builder (within waypoints)
    private var currentAirspaceName: String = ""
    private var currentAirspaceICAOCode: String?
    private var currentAirspaceType: String?
    private var currentAirspaceTransition: String?
    private var currentAirspaceDistanceWithin: ARINCDistance?
    private var currentAirspaceDistanceToEntry: ARINCDistance?
    private var currentAirspaceDistanceToExit: ARINCDistance?
    private var inAirspaceTraversal = false

    // Runway builder (AirportDataList)
    private var currentRunwayIdentifier: String = ""
    private var currentRunwayLDA: ARINCDistance?
    private var currentRunwayApproved: Bool = false
    private var inRunway = false

    // Remark builder
    private var currentRemarkType: String = ""
    private var remarkTextBuffer: String = ""

    // MARK: - Public API

    /// Parse FlightPlan XML data into a FlightPlan model.
    func parse(data: Data) throws -> FlightPlan {
        flightPlan = FlightPlan()
        currentSection = .none
        try run(data: data)
        return flightPlan
    }

    // MARK: - SAXParserEngine Overrides

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        // Capture Value attributes
        if elementName == "Value" {
            currentValueUnit = attributes["unit"] ?? ""
            currentValueType = attributes["type"] ?? ""
        }

        switch elementName {
        // Root element attributes
        case "FlightPlan":
            flightPlan.flightPlanId = attributes["flightPlanId"]
            flightPlan.computedTime = attributes["computedTime"]
            flightPlan.category = attributes["category"]
            flightPlan.validUntil = attributes["validUntil"]

        // M633Header
        case "M633Header":
            flightPlan.header = ARINC633Header(
                versionNumber: attributes["versionNumber"] ?? "",
                timestamp: attributes["timestamp"] ?? ""
            )

        // M633SupplementaryHeader Flight
        case "Flight" where !inWaypoint:
            let flight = ARINCHeaderFlight(
                scheduledDepartureTime: attributes["scheduledTimeOfDeparture"],
                flightOriginDate: attributes["flightOriginDate"]
            )
            flightPlan.supplementaryHeader = SupplementaryHeader(
                flight: flight,
                aircraft: flightPlan.supplementaryHeader.aircraft
            )

        // Aircraft
        case "Aircraft" where currentSection == .none || currentSection == .flightInfo:
            let aircraft = ARINCHeaderAircraft(
                registration: attributes["aircraftRegistration"] ?? ""
            )
            flightPlan.supplementaryHeader = SupplementaryHeader(
                flight: flightPlan.supplementaryHeader.flight,
                aircraft: aircraft
            )

        case "AircraftModel":
            if currentSection == .none || currentSection == .flightInfo {
                let existing = flightPlan.supplementaryHeader.aircraft
                let aircraft = ARINCHeaderAircraft(
                    registration: existing.registration,
                    aircraftType: existing.aircraftType,
                    engineType: attributes["airlineSpecificSubType"]
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: flightPlan.supplementaryHeader.flight,
                    aircraft: aircraft
                )
            }

        // FlightNumber attributes (airlineIATACode, number)
        case "FlightNumber" where !inWaypoint:
            let existing = flightPlan.supplementaryHeader.flight
            flightPlan.supplementaryHeader = SupplementaryHeader(
                flight: ARINCHeaderFlight(
                    airlineCode: attributes["airlineIATACode"] ?? existing.airlineCode,
                    flightNumber: attributes["number"] ?? existing.flightNumber,
                    flightIdentifier: existing.flightIdentifier,
                    commercialFlightNumber: existing.commercialFlightNumber,
                    departure: existing.departure,
                    arrival: existing.arrival,
                    scheduledDepartureTime: existing.scheduledDepartureTime,
                    flightOriginDate: existing.flightOriginDate
                ),
                aircraft: flightPlan.supplementaryHeader.aircraft
            )

        // FlightInfo
        case "FlightInfo":
            currentSection = .flightInfo
            flightPlan.captain = attributes["captain"]
            flightPlan.atcCallsign = attributes["aTCCallsign"]
            flightPlan.selcal = attributes["sELCAL"]

        // CrewList inside FlightInfo (633-5 embedded crew data)
        case "CrewList" where currentSection == .flightInfo:
            inCrewList = true

        case "CrewMember" where inCrewList && currentSection == .flightInfo:
            let member = FlightPlanCrewMember(
                name: attributes["name"] ?? "",
                dutyCode: attributes["dutyCode"] ?? "",
                licenseNumber: attributes["licenseNumber"],
                employeeId: attributes["employeeId"],
                isCockpitCrew: attributes["cockpitCrew"]?.lowercased() == "true"
            )
            flightPlan.crewList.append(member)

        // Top-level Remarks (before FlightPlanHeader)
        case "Remarks" where currentSection == .none || currentSection == .flightInfo:
            currentSection = .remarks

        case "Remark":
            currentRemarkType = attributes["remarkType"] ?? "general"
            remarkTextBuffer = ""

        // FlightPlanHeader
        case "FlightPlanHeader":
            currentSection = .flightPlanHeader
            flightPlan.flightPlanHeader = FlightPlanHeader()

        case "RouteInformation" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.fmsRouteName = attributes["fMSRouteName"]
            flightPlan.flightPlanHeader?.routeName = attributes["routeName"]
            flightPlan.flightPlanHeader?.optimization = attributes["optimization"]

        case "ClimbProcedure" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.climbProcedure = attributes["procedure"]

        case "CruiseProcedure" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.cruiseProcedure = attributes["procedure"]

        case "DescentProcedure" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.descentProcedure = attributes["procedure"]

        // CostInformation (633-5) inside FlightPlanHeader
        case "CostInformation" where currentSection == .flightPlanHeader:
            inCostInformation = true
            costCurrency = attributes["currency"] ?? ""
            costTotal = nil
            costFuel = nil
            costTime = nil
            costDelay = nil
            costEnroute = nil
            costOtherQualifier = ""
            costOthers = []

        case "OtherCost" where inCostInformation:
            costOtherQualifier = attributes["qualifier"] ?? ""

        // EnvironmentalImpactFactors (633-5) inside FlightPlanHeader
        case "EnvironmentalImpactFactors" where currentSection == .flightPlanHeader:
            inEnvironmentalImpact = true
            envCO2 = nil
            envEF = nil

        case "MELCDLItem":
            currentMELType = attributes["mELCDLType"] ?? ""
            currentMELRefId = ""
            currentMELTitle = ""
            currentMELHandled = attributes["handled"]?.lowercased() == "true"
            currentMELEffects = []
            melRemarkBuffer = ""
            inMELRemarks = false

        case "Effects" where stackContains("MELCDLItem"):
            inMELEffects = true

        case "Effect" where inMELEffects:
            inEffect = true
            currentEffectIdentifier = attributes["identifier"] ?? ""
            currentEffectValue = attributes["value"]
            currentEffectDescription = ""

        case "Remarks" where stackContains("MELCDLItem") && currentSection == .flightPlanHeader:
            inMELRemarks = true

        case "NavDataValidity" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.navDataValidity = NavDataValidity(
                airacCycleId: attributes["aIRACCycleID"],
                airacCycleStart: attributes["aIRACCycleStart"],
                airacCycleEnd: attributes["aIRACCycleEnd"]
            )

        case "UpperAirDataForecastPeriod" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.upperAirDataForecastStart = attributes["start"]
            flightPlan.flightPlanHeader?.upperAirDataForecastEnd = attributes["end"]

        case "ContingencyPolicy" where currentSection == .fuelHeader:
            flightPlan.fuelHeader?.contingencyPolicy = attributes["policyName"]

        case "RouteInformation" where currentSection == .alternateRoutes:
            currentAlternateRoute?.fmsRouteName = attributes["fMSRouteName"]

        // FuelHeader (main or contingency)
        case "FuelHeader":
            if currentSection == .contingencySaving {
                currentSection = .contingencySavingFuelHeader
                contingencyFuelHeader = FuelHeader()
            } else if currentSection != .contingencySavingFuelHeader {
                currentSection = .fuelHeader
                if flightPlan.fuelHeader == nil {
                    flightPlan.fuelHeader = FuelHeader()
                }
            }

        // Fuel context tracking
        case "TripFuel":
            if currentSection == .fuelHeader { currentFuelContext = "TripFuel" }
            else if currentSection == .contingencySavingFuelHeader { contingencyFuelContext = "TripFuel" }
        case "ContingencyFuel":
            if currentSection == .fuelHeader { currentFuelContext = "ContingencyFuel" }
        case "AlternateFuel":
            if currentSection == .fuelHeader {
                inAlternateFuel = true
                currentAlternateFuel = AlternateFuelEntry()
            } else if currentSection == .contingencySavingFuelHeader {
                inContingencyAlternateFuel = true
                contingencyAlternateFuel = AlternateFuelEntry()
            }
        case "FinalReserve":
            if currentSection == .fuelHeader && inAlternateFuel {
                inFinalReserve = true
            } else if currentSection == .fuelHeader {
                currentFuelContext = "FinalReserve"
            } else if currentSection == .contingencySavingFuelHeader && inContingencyAlternateFuel {
                inContingencyFinalReserve = true
            }
        case "ReserveFuel" where currentSection == .contingencySavingFuelHeader:
            contingencyFuelContext = "ReserveFuel"
        case "TakeOffFuel":
            if currentSection == .fuelHeader { currentFuelContext = "TakeOffFuel" }
        case "TaxiFuel":
            if currentSection == .fuelHeader { currentFuelContext = "TaxiFuel" }
        case "BlockFuel":
            if currentSection == .fuelHeader { currentFuelContext = "BlockFuel" }
        case "ArrivalFuel":
            if currentSection == .fuelHeader { currentFuelContext = "ArrivalFuel" }

        case "LandingFuel":
            if currentSection == .fuelHeader { inLandingFuel = true }

        case "MinimumBlockFuel":
            if currentSection == .fuelHeader { inMinimumBlockFuel = true }

        case "MinimumTakeOffFuel":
            if currentSection == .fuelHeader { inMinimumTakeOffFuel = true }

        case "InformationalFuel":
            if currentSection == .fuelHeader {
                inInformationalFuel = true
                informationalReason = attributes["reason"] ?? ""
                informationalLabel = attributes["label"]
                informationalWeight = nil
                informationalDuration = nil
            }

        case "AdditionalFuel":
            if currentSection == .fuelHeader {
                inAdditionalFuel = true
                currentAdditionalReason = attributes["reason"] ?? ""
                additionalWeight = nil
                additionalDuration = nil
            }

        case "ExtraFuel":
            if currentSection == .fuelHeader {
                inExtraFuel = true
                currentExtraReason = attributes["reason"] ?? ""
                extraWeight = nil
                extraDuration = nil
            }

        // Weight context tracking
        case "WeightHeader":
            currentSection = .weightHeader
            if flightPlan.weightHeader == nil {
                flightPlan.weightHeader = WeightHeader()
            }
        case "DryOperatingWeight" where currentSection == .weightHeader:
            currentWeightContext = "DryOperatingWeight"
        case "Load" where currentSection == .weightHeader:
            currentWeightContext = "Load"
        case "ZeroFuelWeight" where currentSection == .weightHeader:
            currentWeightContext = "ZeroFuelWeight"
        case "TaxiWeight" where currentSection == .weightHeader:
            currentWeightContext = "TaxiWeight"
        case "TakeoffWeight" where currentSection == .weightHeader:
            currentWeightContext = "TakeoffWeight"
        case "LandingWeight" where currentSection == .weightHeader:
            currentWeightContext = "LandingWeight"

        // Waypoints
        case "Waypoints":
            if currentSection == .alternateRoutes {
                inAlternateRouteWaypoints = true
            } else if currentSection == .contingencySaving || currentSection == .contingencySavingFuelHeader {
                currentSection = .contingencySavingWaypoints
            } else {
                currentSection = .waypoints
            }

        case "Waypoint":
            inWaypoint = true
            // Prefer waypointId for name (short identifier like "ELLX", "LNO").
            // waypointName is the long form (e.g., "LUXEMBOURG", "OLNO") — use as fallback.
            let wpName = attributes["waypointId"]
                ?? attributes["waypointName"]
                ?? ""
            var wp = Waypoint(
                name: wpName,
                sequenceId: Int(attributes["sequenceId"] ?? "0") ?? 0
            )
            wp.countryICAOCode = attributes["countryICAOCode"]
            wp.waypointId = attributes["waypointId"]
            currentWaypoint = wp
            windDirection = nil
            windSpeed = nil

        case "Coordinates" where inWaypoint && !inAirspaceTraversal:
            if let lat = Double(attributes["latitude"] ?? ""),
               let lon = Double(attributes["longitude"] ?? "") {
                currentWaypoint?.coordinate = ARINCCoordinate(
                    latitudeArcSeconds: lat,
                    longitudeArcSeconds: lon
                )
            }

        case "Airspace" where inWaypoint:
            currentAirspaceName = ""
            currentAirspaceICAOCode = attributes["airspaceICAOCode"]
            currentAirspaceType = attributes["airspaceType"]
            currentAirspaceTransition = nil
            currentAirspaceDistanceWithin = nil
            currentAirspaceDistanceToEntry = nil
            currentAirspaceDistanceToExit = nil

        case "TraversalInformation" where inWaypoint:
            inAirspaceTraversal = true
            currentAirspaceTransition = attributes["transition"]

        case "RNP" where inWaypoint:
            currentWaypoint?.rnp = attributes["rnpValue"].flatMap(Double.init)

        case "MaximumSegmentTurbulence" where inWaypoint:
            currentWaypoint?.maximumSegmentTurbulence = attributes["edr"].flatMap(Double.init)

        // Airport elements in various contexts
        case "DepartureAirport":
            if !inWaypoint && (currentSection == .none || currentSection == .flightInfo) {
                // Supplementary header departure -- capture name attribute
                let name = attributes["airportName"]
                let existing = flightPlan.supplementaryHeader.flight
                let dept = ARINCHeaderAirport(
                    icaoCode: existing.departure.icaoCode,
                    iataCode: existing.departure.iataCode,
                    name: name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: dept,
                        arrival: existing.arrival,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }

        case "ArrivalAirport":
            if !inWaypoint && (currentSection == .none || currentSection == .flightInfo) {
                // Supplementary header arrival -- capture name attribute
                let name = attributes["airportName"]
                let existing = flightPlan.supplementaryHeader.flight
                let arr = ARINCHeaderAirport(
                    icaoCode: existing.arrival.icaoCode,
                    iataCode: existing.arrival.iataCode,
                    name: name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: existing.departure,
                        arrival: arr,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }

        case "Airport":
            if inAdequateAirport {
                currentAdequateAirport?.airportName = attributes["airportName"]
            } else if inSuitableAirport {
                currentSuitableAirport?.airportName = attributes["airportName"]
                currentSuitableAirport?.airportFunction = attributes["airportFunction"]
            } else if currentSection == .airportDataList {
                currentAirportData?.airportName = attributes["airportName"]
                let fn = attributes["airportFunction"] ?? ""
                currentAirportData?.airportFunction = AirportFunction(rawValue: fn)
            } else if currentSection == .alternateRoutes && !inWaypoint {
                currentAlternateRoute?.airportName = attributes["airportName"]
                currentAlternateRoute?.airportFunction = attributes["airportFunction"]
            } else if currentSection == .contingencySaving || currentSection == .contingencySavingFuelHeader {
                // ContingencySaving airport
            } else if inAlternateFuel && currentSection == .fuelHeader {
                currentAlternateFuel.airportName = attributes["airportName"]
                currentAlternateFuel.airportFunction = attributes["airportFunction"]
            } else if inContingencyAlternateFuel && currentSection == .contingencySavingFuelHeader {
                contingencyAlternateFuel.airportName = attributes["airportName"]
                contingencyAlternateFuel.airportFunction = attributes["airportFunction"]
            }

        case "ContingencySavingAirport":
            if currentSection == .contingencySaving {
                contingencySaving.airportName = attributes["airportName"]
                contingencySaving.airportFunction = attributes["airportFunction"]
            }

        case "ContingencyPolicy" where currentSection == .contingencySavingFuelHeader:
            contingencyFuelHeader.contingencyPolicy = attributes["policyName"]

        // FlightPlanSummary
        case "FlightPlanSummary":
            currentSection = .summary
            flightPlan.summary = FlightPlanSummary()

        // AlternateRoutes
        case "AlternateRoutes":
            currentSection = .alternateRoutes

        case "AlternateRoute":
            currentAlternateRoute = AlternateRoute()

        // AirportDataList
        case "AirportDataList":
            currentSection = .airportDataList

        case "AirportData":
            currentAirportData = AirportData()

        case "TerminalProcedure":
            if currentSection == .airportDataList, let procType = attributes["procedureType"] {
                // Will capture name in didEndElement
                _ = procType
            }

        case "Runway" where currentSection == .airportDataList:
            inRunway = true
            currentRunwayIdentifier = attributes["runwayIdentifier"] ?? ""
            currentRunwayLDA = nil
            currentRunwayApproved = false

        case "AirportReferencePoint" where currentSection == .airportDataList:
            break // Coordinates handled below

        case "Coordinates" where currentSection == .airportDataList && !inWaypoint:
            if let lat = Double(attributes["latitude"] ?? ""),
               let lon = Double(attributes["longitude"] ?? "") {
                currentAirportData?.referencePoint = ARINCCoordinate(
                    latitudeArcSeconds: lat,
                    longitudeArcSeconds: lon
                )
            }
            if let magVar = attributes["magneticVariation"].flatMap(Double.init) {
                currentAirportData?.magneticVariation = magVar
            }

        case "SuitablePeriod" where currentSection == .airportDataList:
            currentAirportData?.suitablePeriodFrom = attributes["from"]
            currentAirportData?.suitablePeriodUntil = attributes["until"]

        // ContingencySavingHeader
        case "ContingencySavingHeader":
            currentSection = .contingencySaving
            contingencySaving = ContingencySaving()

        // ETOPSSummary
        case "ETOPSSummary":
            currentSection = .etopsSummary
            let wasETOPS = flightPlan.etopsSummary?.isETOPS ?? false
            flightPlan.etopsSummary = ETOPSSummary()
            // If ETOPSSummary has a ruleTime attribute, this is an ETOPS flight
            // (EFF XMLs have ETOPSSummary without NonStandardFlightPlanningType)
            if let ruleTimeStr = attributes["ruleTime"] {
                flightPlan.etopsSummary?.ruleTime = ARINC633Duration(from: ruleTimeStr)
                flightPlan.etopsSummary?.isETOPS = true
            } else {
                flightPlan.etopsSummary?.isETOPS = wasETOPS
            }

        case "CriticalPositions" where currentSection == .etopsSummary:
            inCriticalPositions = true

        case "SuitableAirport" where currentCriticalPosition != nil:
            inSuitableAirport = true
            var airport = ETOPSSuitableAirport()
            airport.relativeLocation = attributes["relativeLocation"]
            currentSuitableAirport = airport

        case "AdequateAirport" where currentCriticalPosition != nil && !inSuitableAirport:
            inAdequateAirport = true
            var airport = AdequateAirport()
            airport.relativeLocation = attributes["relativeLocation"]
            airport.isCriticalFuelEnRouteAlternate = attributes["isCriticalFuelEnRouteAlternate"]?.lowercased() == "true"
            currentAdequateAirport = airport

        case "TerrainAvoidance" where (inSuitableAirport || inAdequateAirport) && inCriticalPositions:
            inTerrainAvoidance = true

        case "SafeAltitude" where inTerrainAvoidance:
            inSafeAltitude = true
            currentSafeAltitudeValue = nil
            currentSafeAltitudeDistance = nil

        case "CriticalPosition" where inCriticalPositions:
            var cp = CriticalPosition()
            cp.sequenceId = attributes["sequenceId"].flatMap(Int.init)
            cp.criticalPositionType = attributes["criticalPositionType"]
            currentCriticalPosition = cp

        case "Coordinates" where currentCriticalPosition != nil && !inSuitableAirport && !inAdequateAirport:
            currentCriticalPosition?.latitude = attributes["latitude"].flatMap(Double.init)
            currentCriticalPosition?.longitude = attributes["longitude"].flatMap(Double.init)

        default:
            break
        }
    }

    override func handleEndElement(_ elementName: String, text: String) {
        let unit = currentValueUnit
        let type = currentValueType

        switch elementName {

        // Root element - done
        case "FlightPlan":
            break

        // Header identifiers
        case "FlightIdentifier":
            if !inWaypoint {
                let existing = flightPlan.supplementaryHeader.flight
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: text,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: existing.departure,
                        arrival: existing.arrival,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }

        case "CommercialFlightNumber":
            if !inWaypoint {
                let existing = flightPlan.supplementaryHeader.flight
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: text,
                        departure: existing.departure,
                        arrival: existing.arrival,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }

        case "AirportICAOCode":
            handleAirportICAOCode(text)

        case "AirportIATACode":
            handleAirportIATACode(text)

        case "AircraftICAOType":
            if currentSection == .none || currentSection == .flightInfo {
                let existing = flightPlan.supplementaryHeader.aircraft
                let aircraft = ARINCHeaderAircraft(
                    registration: existing.registration,
                    aircraftType: text,
                    engineType: existing.engineType
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: flightPlan.supplementaryHeader.flight,
                    aircraft: aircraft
                )
            }

        // Text content within remarks
        case "Text":
            if inMELRemarks && stackContains("Remark") {
                // Accumulate MEL remark text
                if melRemarkBuffer.isEmpty {
                    melRemarkBuffer = text
                } else {
                    melRemarkBuffer += "\n" + text
                }
            } else if stackContains("Remark") {
                if remarkTextBuffer.isEmpty {
                    remarkTextBuffer = text
                } else {
                    remarkTextBuffer += "\n" + text
                }
            }

        // Remark end -- capture accumulated text
        case "Remark":
            if inMELRemarks {
                // MEL remark text accumulates in melRemarkBuffer; nothing to do per-Remark
            } else if currentSection == .remarks {
                let trimmed = remarkTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let remark = FlightPlanRemark(remarkType: currentRemarkType, text: trimmed)
                    flightPlan.remarks.append(remark)
                }
                remarkTextBuffer = ""
            } else if currentSection == .fuelHeader {
                let trimmed = remarkTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    flightPlan.fuelHeader?.remarks.append(trimmed)
                }
                remarkTextBuffer = ""
            }

        // Description inside Effect
        case "Description" where inEffect && inMELEffects:
            currentEffectDescription = text

        // Effect end -- build and append MELEffect
        case "Effect" where inMELEffects:
            let effect = MELEffect(
                identifier: currentEffectIdentifier,
                value: currentEffectValue,
                description: currentEffectDescription
            )
            currentMELEffects.append(effect)
            inEffect = false

        // Effects end
        case "Effects" where stackContains("MELCDLItem"):
            inMELEffects = false

        // Remarks section end
        case "Remarks":
            if inMELRemarks {
                inMELRemarks = false
            } else if currentSection == .remarks {
                currentSection = .none
            }

        // FlightPlanHeader elements
        case "AuthorName" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.authorName = text.trimmedOrNil

        case "EmailAddress" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.authorEmail = text.trimmedOrNil

        case "DispatchOffice" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.dispatchOffice = text.trimmedOrNil

        case "PerformanceFactor" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.performanceFactor = text.toDouble

        case "EngineId" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.engineId = text.trimmedOrNil

        case "VerticalProfileDescription" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.verticalProfileDescription = text.trimmedOrNil

        case "Policy" where currentSection == .flightPlanHeader:
            if let trimmed = text.trimmedOrNil {
                flightPlan.flightPlanHeader?.regulationPolicies.append(trimmed)
            }

        case "RouteDescription" where currentSection == .flightPlanHeader:
            flightPlan.flightPlanHeader?.routeDescription = text.trimmedOrNil

        case "RouteDescription" where currentSection == .alternateRoutes:
            currentAlternateRoute?.routeDescription = text.trimmedOrNil

        case "ReferenceId":
            currentMELRefId = text

        case "Title" where currentSection == .flightPlanHeader:
            currentMELTitle = text

        case "MELCDLItem":
            if currentSection == .flightPlanHeader {
                let trimmedRemark = melRemarkBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                let item = MELCDLItem(
                    type: currentMELType,
                    referenceId: currentMELRefId,
                    title: currentMELTitle,
                    remark: trimmedRemark.isEmpty ? nil : trimmedRemark,
                    handled: currentMELHandled,
                    effects: currentMELEffects
                )
                flightPlan.flightPlanHeader?.melCdlItems.append(item)
            }

        // CostInformation child elements (633-5)
        case "TotalCostOfFlight" where inCostInformation:
            costTotal = text.toDouble

        case "FuelCost" where inCostInformation:
            costFuel = text.toDouble

        case "TimeCost" where inCostInformation:
            costTime = text.toDouble

        case "DelayCost" where inCostInformation:
            costDelay = text.toDouble

        case "EnrouteCharges" where inCostInformation:
            costEnroute = text.toDouble

        case "OtherCost" where inCostInformation:
            if let value = text.toDouble {
                costOthers.append(OtherCost(qualifier: costOtherQualifier, value: value))
            }
            costOtherQualifier = ""

        case "CostInformation" where inCostInformation:
            flightPlan.flightPlanHeader?.costInformation = CostInformation(
                currency: costCurrency,
                totalCost: costTotal,
                fuelCost: costFuel,
                timeCost: costTime,
                delayCost: costDelay,
                enrouteCharges: costEnroute,
                otherCosts: costOthers
            )
            inCostInformation = false

        // EnvironmentalImpactFactors child elements (633-5)
        case "CO2" where inEnvironmentalImpact:
            envCO2 = text.toDouble

        case "EF" where inEnvironmentalImpact:
            envEF = text.toDouble

        case "EnvironmentalImpactFactors" where inEnvironmentalImpact:
            flightPlan.flightPlanHeader?.environmentalImpact = EnvironmentalImpact(
                co2Tonnes: envCO2,
                energyFactor: envEF
            )
            inEnvironmentalImpact = false

        case "FlightPlanHeader":
            currentSection = .none

        // Value element -- context-dependent
        case "Value":
            handleValueElement(text, unit: unit, type: type)

        // Function within waypoints
        case "Function":
            if inWaypoint {
                currentWaypoint?.functions.append(WaypointFunction(rawValue: text))
            }

        // Airway within waypoints
        case "Airway":
            if inWaypoint {
                currentWaypoint?.airway = text.trimmedOrNil
            }

        // Sequence within fuel
        case "Sequence":
            if currentSection == .fuelHeader && inAlternateFuel {
                currentAlternateFuel.sequence = text.toInt
            }

        // End of fuel contexts
        case "TripFuel":
            if currentSection == .fuelHeader { currentFuelContext = "" }
            else if currentSection == .contingencySavingFuelHeader { contingencyFuelContext = "" }
        case "ContingencyFuel":
            if currentSection == .fuelHeader { currentFuelContext = "" }
        case "FinalReserve":
            if currentSection == .fuelHeader {
                if inAlternateFuel { inFinalReserve = false }
                else { currentFuelContext = "" }
            } else if currentSection == .contingencySavingFuelHeader {
                inContingencyFinalReserve = false
            }
        case "TakeOffFuel", "TaxiFuel", "BlockFuel", "ArrivalFuel":
            if currentSection == .fuelHeader { currentFuelContext = "" }

        case "LandingFuel":
            if currentSection == .fuelHeader { inLandingFuel = false }

        case "MinimumBlockFuel":
            if currentSection == .fuelHeader { inMinimumBlockFuel = false }

        case "MinimumTakeOffFuel":
            if currentSection == .fuelHeader { inMinimumTakeOffFuel = false }

        case "InformationalFuel":
            if currentSection == .fuelHeader && inInformationalFuel {
                let item = InformationalFuel(
                    reason: informationalReason,
                    label: informationalLabel,
                    weight: informationalWeight,
                    duration: informationalDuration
                )
                flightPlan.fuelHeader?.informationalFuels.append(item)
                inInformationalFuel = false
            }
        case "ReserveFuel" where currentSection == .contingencySavingFuelHeader:
            contingencyFuelContext = ""

        case "AlternateFuel":
            if currentSection == .fuelHeader && inAlternateFuel {
                flightPlan.fuelHeader?.alternateFuels.append(currentAlternateFuel)
                inAlternateFuel = false
                currentAlternateFuel = AlternateFuelEntry()
            } else if currentSection == .contingencySavingFuelHeader && inContingencyAlternateFuel {
                contingencyFuelHeader.alternateFuels.append(contingencyAlternateFuel)
                inContingencyAlternateFuel = false
                contingencyAlternateFuel = AlternateFuelEntry()
            }

        case "AdditionalFuel":
            if currentSection == .fuelHeader && inAdditionalFuel {
                let item = AdditionalFuelItem(
                    reason: FuelCategory(rawValue: currentAdditionalReason),
                    weight: additionalWeight,
                    duration: additionalDuration
                )
                flightPlan.fuelHeader?.additionalFuels.append(item)
                inAdditionalFuel = false
            }

        case "ExtraFuel":
            if currentSection == .fuelHeader && inExtraFuel {
                let item = ExtraFuelItem(
                    reason: FuelCategory(rawValue: currentExtraReason),
                    weight: extraWeight,
                    duration: extraDuration
                )
                flightPlan.fuelHeader?.extraFuels.append(item)
                inExtraFuel = false
            }

        case "FuelHeader":
            if currentSection == .contingencySavingFuelHeader {
                contingencySaving.fuelHeader = contingencyFuelHeader
                currentSection = .contingencySaving
            } else if currentSection == .fuelHeader {
                currentSection = .none
            }

        // Weight context resets
        case "DryOperatingWeight" where currentSection == .weightHeader:
            currentWeightContext = ""
        case "Load" where currentSection == .weightHeader:
            currentWeightContext = ""
        case "ZeroFuelWeight" where currentSection == .weightHeader:
            currentWeightContext = ""
        case "TaxiWeight" where currentSection == .weightHeader:
            currentWeightContext = ""
        case "TakeoffWeight" where currentSection == .weightHeader:
            currentWeightContext = ""
        case "LandingWeight" where currentSection == .weightHeader:
            currentWeightContext = ""

        case "Reason" where currentSection == .weightHeader:
            if currentWeightContext == "TakeoffWeight" {
                flightPlan.weightHeader?.towLimitReason = text.trimmedOrNil
            } else if currentWeightContext == "LandingWeight" {
                flightPlan.weightHeader?.ldwLimitReason = text.trimmedOrNil
            }

        case "WeightHeader":
            // Build convenience WeightData from parsed WeightHeader
            if let wh = flightPlan.weightHeader {
                var wd = WeightData()
                wd.dryOperatingWeight = wh.dryOperatingWeight.estimated
                wd.zeroFuelWeight = wh.zeroFuelWeight.estimated
                wd.basicWeight = wh.basicWeight
                wd.cargoLoad = wh.cargoLoad
                wd.paxLoad = wh.paxLoad
                wd.taxiWeight = wh.taxiWeight.estimated
                wd.takeoffWeight = wh.takeoffWeight.estimated
                wd.landingWeight = wh.landingWeight.estimated
                wd.structuralLimit = wh.towStructuralLimit
                wd.operationalLimit = wh.towOperationalLimit
                flightPlan.weightData = wd
            }
            currentSection = .none

        // Airspace traversal end
        case "Airspace" where inWaypoint:
            let traversal = AirspaceTraversal(
                airspaceName: currentAirspaceName,
                airspaceICAOCode: currentAirspaceICAOCode,
                airspaceType: currentAirspaceType,
                transition: currentAirspaceTransition,
                distanceWithin: currentAirspaceDistanceWithin,
                distanceToEntry: currentAirspaceDistanceToEntry,
                distanceToExit: currentAirspaceDistanceToExit
            )
            currentWaypoint?.airspaceTraversals.append(traversal)
            inAirspaceTraversal = false
            currentAirspaceName = ""
            currentAirspaceICAOCode = nil
            currentAirspaceType = nil
            currentAirspaceTransition = nil
            currentAirspaceDistanceWithin = nil
            currentAirspaceDistanceToEntry = nil
            currentAirspaceDistanceToExit = nil

        case "AirspaceName" where inWaypoint:
            currentAirspaceName = text

        case "TraversalInformation" where inWaypoint:
            inAirspaceTraversal = false

        case "NavaidFrequencies" where inWaypoint:
            break // frequencies accumulated via Frequency element

        case "Frequency" where inWaypoint:
            if let freq = text.toDouble {
                currentWaypoint?.navaidFrequencies.append(freq)
            }

        // End waypoint
        case "Waypoint":
            if let wp = currentWaypoint {
                // Finalize wind from accumulated direction + speed
                if let dir = windDirection, let spd = windSpeed {
                    currentWaypoint?.wind = ARINCWind(direction: dir, speed: spd)
                }

                let finalWp = currentWaypoint ?? wp

                if currentSection == .contingencySavingWaypoints {
                    contingencySaving.waypoints.append(finalWp)
                } else if inAlternateRouteWaypoints {
                    currentAlternateRoute?.waypoints.append(finalWp)
                } else if currentSection == .waypoints {
                    flightPlan.waypoints.append(finalWp)
                }
            }
            currentWaypoint = nil
            inWaypoint = false
            windDirection = nil
            windSpeed = nil

        // Waypoints section end
        case "Waypoints":
            if currentSection == .contingencySavingWaypoints {
                currentSection = .contingencySaving
            } else if inAlternateRouteWaypoints {
                inAlternateRouteWaypoints = false
            } else if currentSection == .waypoints {
                currentSection = .none
            }

        // FlightPlanSummary elements
        case "ScheduledTimeOfArrival" where currentSection == .summary:
            flightPlan.summary?.scheduledTimeOfArrival = text.trimmedOrNil

        case "FlightPlanSummary":
            currentSection = .none

        // NonStandardFlightPlanningType
        case "ETOPS" where stackContains("NonStandardFlightPlanningType"):
            if text.lowercased() == "true" {
                if flightPlan.etopsSummary == nil {
                    flightPlan.etopsSummary = ETOPSSummary()
                }
                flightPlan.etopsSummary?.isETOPS = true
            }

        case "ContingencySaving" where stackContains("NonStandardFlightPlanningType"):
            flightPlan.contingencySavingType = text.trimmedOrNil

        // AlternateRoute end
        case "AlternateRoute":
            if let route = currentAlternateRoute {
                flightPlan.alternateRoutes.append(route)
            }
            currentAlternateRoute = nil

        case "AlternateRoutes":
            currentSection = .none

        // AirportData elements
        case "PlannedRunway" where currentSection == .airportDataList:
            currentAirportData?.plannedRunway = text.trimmedOrNil

        case "MagneticVariation" where currentSection == .airportDataList:
            currentAirportData?.magneticVariation = text.toDouble

        case "Elevation" where currentSection == .airportDataList:
            if let v = text.toDouble {
                currentAirportData?.elevation = ARINCAltitude(value: v, unit: currentValueUnit.isEmpty ? "ft" : currentValueUnit)
            }

        case "LocalTimeOffsetToUTC" where currentSection == .airportDataList:
            currentAirportData?.localTimeOffsetToUTC = text.trimmedOrNil

        case "Suitable" where currentSection == .airportDataList:
            currentAirportData?.suitable = text.lowercased() == "true"

        case "LandingDistanceAvailable" where inRunway && currentSection == .airportDataList:
            if let v = text.toDouble {
                currentRunwayLDA = ARINCDistance(value: v, unit: currentValueUnit.isEmpty ? "m" : currentValueUnit)
            }

        case "ApprovedForRegularOperation" where inRunway && currentSection == .airportDataList:
            currentRunwayApproved = text.lowercased() == "true"

        case "Runway" where currentSection == .airportDataList:
            if inRunway {
                let runway = RunwayInfo(
                    identifier: currentRunwayIdentifier,
                    landingDistanceAvailable: currentRunwayLDA,
                    approvedForRegularOperation: currentRunwayApproved
                )
                currentAirportData?.runways.append(runway)
                inRunway = false
            }

        case "TerminalProcedure" where currentSection == .airportDataList:
            let procType = currentAttributes["procedureType"] ?? ""
            if !text.isEmpty {
                currentAirportData?.terminalProcedures.append(
                    TerminalProcedure(procedureType: procType, name: text)
                )
            }

        case "AirportData":
            if let ad = currentAirportData {
                flightPlan.airportData.append(ad)
            }
            currentAirportData = nil

        case "AirportDataList":
            currentSection = .none

        // ETOPS Critical Position elements
        case "PositionName" where currentCriticalPosition != nil && !inSuitableAirport && !inAdequateAirport:
            currentCriticalPosition?.positionName = text.trimmedOrNil

        // Coordinates is handled in handleStartElement for self-closing tag

        case "Condition" where currentCriticalPosition != nil:
            currentCriticalPosition?.condition = text.trimmedOrNil

        // SafeAltitude end — collect value and distance into a SafeAltitude struct
        case "SafeAltitude" where inTerrainAvoidance:
            if let alt = currentSafeAltitudeValue {
                let sa = SafeAltitude(
                    method: nil,
                    altitude: alt,
                    greatCircleDistanceFromAirport: currentSafeAltitudeDistance
                )
                if inSuitableAirport {
                    currentSuitableAirport?.safeAltitudes.append(sa)
                } else if inAdequateAirport {
                    currentAdequateAirport?.safeAltitudes.append(sa)
                }
            }
            inSafeAltitude = false
            currentSafeAltitudeValue = nil
            currentSafeAltitudeDistance = nil

        case "TerrainAvoidance" where inCriticalPositions:
            inTerrainAvoidance = false

        case "SuitableAirport" where currentCriticalPosition != nil:
            if let airport = currentSuitableAirport {
                currentCriticalPosition?.suitableAirports.append(airport)
            }
            currentSuitableAirport = nil
            inSuitableAirport = false

        case "AdequateAirport" where currentCriticalPosition != nil:
            if let airport = currentAdequateAirport {
                currentCriticalPosition?.adequateAirports.append(airport)
            }
            currentAdequateAirport = nil
            inAdequateAirport = false

        case "CriticalPosition" where inCriticalPositions:
            if let cp = currentCriticalPosition {
                flightPlan.etopsSummary?.criticalPositions.append(cp)
            }
            currentCriticalPosition = nil

        case "CriticalPositions":
            inCriticalPositions = false

        case "ETOPSSummary":
            currentSection = .none

        // ContingencySavingHeader elements
        case "Name" where currentSection == .contingencySaving && parent == "DecisionPoint":
            contingencySaving.decisionPointName = text.trimmedOrNil

        case "ContingencySavingHeader":
            contingencySaving.waypoints = contingencySaving.waypoints
            flightPlan.contingencySaving = contingencySaving
            currentSection = .none

        // CrewList end (633-5 embedded crew)
        case "CrewList" where inCrewList:
            inCrewList = false

        // FlightInfo end
        case "FlightInfo":
            if currentSection == .flightInfo {
                currentSection = .none
            }

        default:
            break
        }
    }

    // MARK: - Value Element Handling

    private func handleValueElement(_ text: String, unit: String, type: String) {
        switch currentSection {
        case .flightPlanHeader:
            handleFlightPlanHeaderValue(text, unit: unit, type: type)
        case .fuelHeader:
            handleFuelValue(text, unit: unit)
        case .contingencySavingFuelHeader:
            handleContingencyFuelValue(text, unit: unit)
        case .weightHeader:
            handleWeightValue(text, unit: unit)
        case .waypoints, .contingencySavingWaypoints:
            if inWaypoint {
                handleWaypointValue(text, unit: unit, type: type)
            }
        case .alternateRoutes:
            if inWaypoint {
                handleWaypointValue(text, unit: unit, type: type)
            } else {
                handleAlternateRouteValue(text, unit: unit)
            }
        case .summary:
            handleSummaryValue(text)
        case .etopsSummary:
            handleETOPSValue(text, unit: unit)
        case .contingencySaving:
            handleContingencySavingValue(text, unit: unit)
        default:
            break
        }
    }

    // MARK: - FlightPlanHeader Values

    private func handleFlightPlanHeaderValue(_ text: String, unit: String, type: String) {
        let p = parent
        let gp = grandparent

        switch p {
        case "AverageFuelFlow":
            flightPlan.flightPlanHeader?.averageFuelFlow = ARINCFlow(
                value: text.toDouble ?? 0, unit: unit
            )
        case "HoldingFuelFlow":
            flightPlan.flightPlanHeader?.holdingFuelFlow = ARINCFlow(
                value: text.toDouble ?? 0, unit: unit
            )
        case "Direction" where gp == "AverageWind":
            flightPlan.flightPlanHeader?.averageWindDirection = text.toDouble
        case "Speed" where gp == "AverageWind":
            flightPlan.flightPlanHeader?.averageWindSpeed = ARINCSpeed(
                value: text.toDouble ?? 0, unit: unit
            )
        case "AverageWindComponent":
            flightPlan.flightPlanHeader?.averageWindComponent = ARINCSpeed(
                value: text.toDouble ?? 0, unit: unit
            )
        case "AverageTemperature":
            flightPlan.flightPlanHeader?.averageTemperature = ARINCTemperature(
                value: text.toDouble ?? 0, unit: unit
            )
        case "AverageISADeviation":
            flightPlan.flightPlanHeader?.averageISADeviation = ARINCTemperature(
                value: text.toDouble ?? 0, unit: unit
            )
        case "InitialAltitude":
            flightPlan.flightPlanHeader?.initialAltitude = ARINCAltitude(
                value: text.toDouble ?? 0, unit: unit
            )
        case "CostIndex":
            flightPlan.flightPlanHeader?.costIndex = text.toInt
        case "GroundDistance":
            flightPlan.flightPlanHeader?.groundDistance = ARINCDistance(
                value: text.toDouble ?? 0, unit: unit
            )
        case "AirDistance":
            flightPlan.flightPlanHeader?.airDistance = ARINCDistance(
                value: text.toDouble ?? 0, unit: unit
            )
        case "GreatCircleDistance":
            flightPlan.flightPlanHeader?.greatCircleDistance = ARINCDistance(
                value: text.toDouble ?? 0, unit: unit
            )
        default:
            break
        }
    }

    // MARK: - Fuel Values

    private func handleFuelValue(_ text: String, unit: String) {
        let p = parent
        let gp = grandparent

        // InformationalFuel handling
        if inInformationalFuel {
            if p == "EstimatedWeight" {
                informationalWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "Duration" || gp == "Duration" {
                informationalDuration = ARINC633Duration(from: text)
            }
            return
        }

        // MinimumBlockFuel handling
        if inMinimumBlockFuel {
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.minimumBlockFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.minimumBlockDuration = ARINC633Duration(from: text)
            }
            return
        }

        // MinimumTakeOffFuel handling
        if inMinimumTakeOffFuel {
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.minimumTakeoffFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.minimumTakeoffDuration = ARINC633Duration(from: text)
            }
            return
        }

        // LandingFuel handling
        if inLandingFuel {
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.landingFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.landingDuration = ARINC633Duration(from: text)
            }
            return
        }

        // Additional fuel handling
        if inAdditionalFuel {
            if p == "EstimatedWeight" {
                additionalWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "Duration" || gp == "Duration" {
                additionalDuration = ARINC633Duration(from: text)
            }
            return
        }

        // Extra fuel handling
        if inExtraFuel {
            if p == "EstimatedWeight" {
                extraWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "Duration" || gp == "Duration" {
                extraDuration = ARINC633Duration(from: text)
            }
            return
        }

        // Final reserve within alternate fuel
        if inFinalReserve && inAlternateFuel {
            if p == "EstimatedWeight" {
                currentAlternateFuel.finalReserveWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "Duration" || gp == "Duration" {
                currentAlternateFuel.finalReserveDuration = ARINC633Duration(from: text)
            }
            return
        }

        // Alternate fuel weight/duration
        if inAlternateFuel {
            if p == "EstimatedWeight" && gp == "AlternateFuel" {
                currentAlternateFuel.weight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if (p == "Duration" || gp == "Duration") && !inFinalReserve {
                currentAlternateFuel.duration = ARINC633Duration(from: text)
            }
            return
        }

        // Standard fuel contexts
        switch currentFuelContext {
        case "TripFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.tripFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.tripDuration = ARINC633Duration(from: text)
            }
        case "ContingencyFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.contingencyFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.contingencyDuration = ARINC633Duration(from: text)
            }
        case "FinalReserve":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.reserveFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.reserveDuration = ARINC633Duration(from: text)
            }
        case "TakeOffFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.takeoffFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.takeoffDuration = ARINC633Duration(from: text)
            }
        case "TaxiFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.taxiFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.taxiDuration = ARINC633Duration(from: text)
            }
        case "BlockFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.blockFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                flightPlan.fuelHeader?.blockDuration = ARINC633Duration(from: text)
            }
        case "ArrivalFuel":
            if p == "EstimatedWeight" {
                flightPlan.fuelHeader?.arrivalFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        default:
            // MaximumFuelWeight inside PossibleExtraFuel
            if p == "Weight" && gp == "MaximumFuelWeight" {
                flightPlan.fuelHeader?.maxExtraFuelWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
                flightPlan.fuelHeader?.possibleExtraFuelWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
            // TankVolume inside PossibleExtraFuel
            if p == "TankVolume" {
                flightPlan.fuelHeader?.tankVolume = ARINCVolume(value: text.toDouble ?? 0, unit: unit)
            }
        }
    }

    // MARK: - Contingency Fuel Values

    private func handleContingencyFuelValue(_ text: String, unit: String) {
        let p = parent

        if inContingencyFinalReserve && inContingencyAlternateFuel {
            if p == "EstimatedWeight" {
                contingencyAlternateFuel.finalReserveWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                contingencyAlternateFuel.finalReserveDuration = ARINC633Duration(from: text)
            }
            return
        }

        if inContingencyAlternateFuel {
            if p == "EstimatedWeight" {
                contingencyAlternateFuel.weight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                contingencyAlternateFuel.duration = ARINC633Duration(from: text)
            }
            return
        }

        switch contingencyFuelContext {
        case "TripFuel":
            if p == "EstimatedWeight" {
                contingencyFuelHeader.tripFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                contingencyFuelHeader.tripDuration = ARINC633Duration(from: text)
            }
        case "ReserveFuel":
            if p == "EstimatedWeight" {
                contingencyFuelHeader.reserveFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if text.hasPrefix("PT") {
                contingencyFuelHeader.reserveDuration = ARINC633Duration(from: text)
            }
        default:
            break
        }
    }

    // MARK: - Weight Values

    private func handleWeightValue(_ text: String, unit: String) {
        let p = parent
        let gp = grandparent

        switch currentWeightContext {
        case "DryOperatingWeight":
            if p == "EstimatedWeight" {
                flightPlan.weightHeader?.dryOperatingWeight.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "BasicWeight" {
                flightPlan.weightHeader?.basicWeight = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        case "Load":
            if p == "EstimatedWeight" && gp == "Load" {
                flightPlan.weightHeader?.load.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if gp == "CargoLoad" {
                flightPlan.weightHeader?.cargoLoad = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if gp == "PaxLoad" {
                flightPlan.weightHeader?.paxLoad = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        case "ZeroFuelWeight":
            if p == "EstimatedWeight" {
                flightPlan.weightHeader?.zeroFuelWeight.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "OperationalLimit" {
                flightPlan.weightHeader?.zfwOperationalLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "StructuralLimit" {
                flightPlan.weightHeader?.zfwStructuralLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        case "TaxiWeight":
            if p == "EstimatedWeight" {
                flightPlan.weightHeader?.taxiWeight.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "StructuralLimit" {
                flightPlan.weightHeader?.taxiWeightStructuralLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        case "TakeoffWeight":
            if p == "EstimatedWeight" {
                flightPlan.weightHeader?.takeoffWeight.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "OperationalLimit" {
                flightPlan.weightHeader?.towOperationalLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "StructuralLimit" {
                flightPlan.weightHeader?.towStructuralLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        case "LandingWeight":
            if p == "EstimatedWeight" {
                flightPlan.weightHeader?.landingWeight.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "OperationalLimit" {
                flightPlan.weightHeader?.ldwOperationalLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            } else if p == "StructuralLimit" {
                flightPlan.weightHeader?.ldwStructuralLimit = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            }
        default:
            break
        }
    }

    // MARK: - Waypoint Values

    private func handleWaypointValue(_ text: String, unit: String, type: String) {
        guard var wp = currentWaypoint else { return }
        let p = parent
        let gp = grandparent

        // Airspace traversal distances — handle before the main switch
        if inAirspaceTraversal {
            switch p {
            case "GroundDistanceWithinAirspace":
                currentAirspaceDistanceWithin = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "GroundDistanceToEntry":
                currentAirspaceDistanceToEntry = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "GroundDistanceToExit":
                currentAirspaceDistanceToExit = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            default:
                break
            }
            // Don't write back wp for airspace values — they go into currentAirspace* vars
            return
        }

        // Safe altitude values inside terrain avoidance (within waypoint context for alternate routes)
        if inSafeAltitude {
            switch p {
            case "Altitude":
                currentSafeAltitudeValue = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
            case "GreatCircleDistanceFromAirport":
                currentSafeAltitudeDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            default:
                break
            }
            return
        }

        switch p {
        // Wind
        case "Direction" where gp == "SegmentWind":
            windDirection = text.toDouble
        case "Speed" where gp == "SegmentWind":
            windSpeed = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
        case "SegmentWindComponent":
            wp.windComponent = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)

        // Temperature
        case "SegmentTemperature":
            wp.temperature = ARINCTemperature(value: text.toDouble ?? 0, unit: unit)
        case "SegmentISADeviation":
            wp.isaDeviation = ARINCTemperature(value: text.toDouble ?? 0, unit: unit)

        // Altitude
        case "Tropopause":
            wp.tropopause = ARINCAltitude(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedAltitude":
            wp.altitude.estimated = ARINCAltitude(value: text.toDouble ?? 0, unit: unit)
        case "MinimumSafeAltitude":
            wp.minimumSafeAltitude = ARINCAltitude(value: text.toDouble ?? 0, unit: unit)

        // Speeds
        case "EstimatedSpeed" where gp == "TrueAirSpeed":
            wp.trueAirSpeed.estimated = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedSpeed" where gp == "IndicatedAirSpeed":
            wp.indicatedAirSpeed.estimated = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedSpeed" where gp == "GroundSpeed":
            wp.groundSpeed.estimated = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedMachNumber":
            wp.mach.estimated = ARINCMachNumber(value: text.toDouble ?? 0)

        // Tracks
        case "OutboundTrack":
            if type == "true" {
                wp.outboundTrueTrack = text.toDouble
            } else if type == "magnetic" {
                wp.outboundMagneticTrack = text.toDouble
            }
        case "InboundTrack":
            if type == "true" {
                wp.inboundTrueTrack = text.toDouble
            } else if type == "magnetic" {
                wp.inboundMagneticTrack = text.toDouble
            }
        case "SegmentTrack":
            if type == "true" {
                wp.segmentTrueTrack = text.toDouble
            } else if type == "magnetic" {
                wp.segmentMagneticTrack = text.toDouble
            }

        // Distances
        case "GroundDistance":
            wp.groundDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
        case "RemainingGroundDistance":
            wp.remainingGroundDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
        case "AirDistance":
            wp.airDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
        case "RemainingAirDistance":
            wp.remainingAirDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)

        // Times
        case "EstimatedTime" where gp == "TimeFromPreviousWaypoint":
            if text.hasPrefix("PT") {
                wp.timeFromPrevious = ARINC633Duration(from: text)
            }
        case "EstimatedTime" where gp == "TimeOverWaypoint":
            wp.timeOverWaypoint = text.trimmedOrNil
        case "EstimatedTime" where gp == "CumulatedFlightTime":
            if text.hasPrefix("PT") {
                wp.cumulatedFlightTime = ARINC633Duration(from: text)
            }
        case "EstimatedTime" where gp == "RemainingFlightTime":
            if text.hasPrefix("PT") {
                wp.remainingFlightTime = ARINC633Duration(from: text)
            }

        // Fuel
        case "EstimatedWeight" where gp == "BurnOff":
            wp.burnOff.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedWeight" where gp == "CumulatedBurnOff":
            wp.cumulatedBurnOff.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
        case "EstimatedWeight" where gp == "FuelOnBoard":
            wp.fuelOnBoard.estimated = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
        case "MinimumFuelOnBoard":
            wp.minimumFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)

        default:
            break
        }

        currentWaypoint = wp
    }

    // MARK: - Summary Values

    private func handleSummaryValue(_ text: String) {
        let gp = grandparent

        switch gp {
        case "OutTime":
            flightPlan.summary?.outTime = text.trimmedOrNil
        case "OffTime":
            flightPlan.summary?.offTime = text.trimmedOrNil
        case "OnTime":
            flightPlan.summary?.onTime = text.trimmedOrNil
        case "InTime":
            flightPlan.summary?.inTime = text.trimmedOrNil
        case "BlockTime":
            flightPlan.summary?.blockTime = ARINC633Duration(from: text)
        case "TaxiOutTime":
            flightPlan.summary?.taxiOutTime = ARINC633Duration(from: text)
        case "FlightTime":
            flightPlan.summary?.flightTime = ARINC633Duration(from: text)
        case "TaxiInTime":
            flightPlan.summary?.taxiInTime = ARINC633Duration(from: text)
        default:
            break
        }
    }

    // MARK: - AlternateRoute Values

    private func handleAlternateRouteValue(_ text: String, unit: String) {
        let p = parent

        switch p {
        case "AverageWindComponent":
            currentAlternateRoute?.averageWindComponent = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
        case "AverageTemperature":
            currentAlternateRoute?.averageTemperature = ARINCTemperature(value: text.toDouble ?? 0, unit: unit)
        case "AverageISADeviation":
            currentAlternateRoute?.averageISADeviation = ARINCTemperature(value: text.toDouble ?? 0, unit: unit)
        case "InitialAltitude":
            currentAlternateRoute?.initialAltitude = ARINCAltitude(value: text.toDouble ?? 0, unit: unit)
        case "GroundDistance":
            currentAlternateRoute?.groundDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
        case "AirDistance":
            currentAlternateRoute?.airDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
        default:
            break
        }
    }

    // MARK: - ContingencySaving Values

    private func handleContingencySavingValue(_ text: String, unit: String) {
        let p = parent
        let gp = grandparent

        switch p {
        case "EstimatedTime" where gp == "TimeOverDecisionPoint":
            contingencySaving.timeOverDecisionPoint = text.trimmedOrNil
        case "EstimatedTime" where gp == "CumulatedFlightTime":
            contingencySaving.cumulatedFlightTime = ARINC633Duration(from: text)
        case "FuelRequiredToArrivalAirport":
            contingencySaving.fuelRequiredToArrival = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
        case "FuelRequiredToContingencySavingAirport":
            contingencySaving.fuelRequiredToContingencySavingAirport = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
        default:
            break
        }
    }

    // MARK: - ETOPS Values

    private func handleETOPSValue(_ text: String, unit: String) {
        let p = parent

        // Safe altitude values — handled first to avoid falling through
        if inSafeAltitude {
            switch p {
            case "Altitude":
                currentSafeAltitudeValue = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
            case "GreatCircleDistanceFromAirport":
                currentSafeAltitudeDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            default:
                break
            }
            return
        }

        if inSuitableAirport {
            // Values within SuitableAirport context
            if inTerrainAvoidance {
                switch p {
                case "MaximumTerrainElevation":
                    currentSuitableAirport?.maximumTerrainElevation = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
                case "MinimumVerticalClearance":
                    currentSuitableAirport?.minimumVerticalClearance = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
                default:
                    break
                }
                return
            }
            switch p {
            case "RemainingFlightTime":
                currentSuitableAirport?.remainingFlightTime = ARINC633Duration(from: text)
            case "RemainingAirDistance":
                currentSuitableAirport?.remainingAirDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "RemainingGroundDistance":
                currentSuitableAirport?.remainingGroundDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "Altitude":
                let rawValue = text.toDouble ?? 0
                currentSuitableAirport?.altitude = ARINCDistance(value: rawValue, unit: unit.isEmpty ? "ft" : unit)
            case "MinimumSafeAltitude":
                let rawValue = text.toDouble ?? 0
                currentSuitableAirport?.minimumSafeAltitude = ARINCDistance(value: rawValue, unit: unit.isEmpty ? "ft" : unit)
            case "TripFuel":
                currentSuitableAirport?.tripFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "FinalReserve":
                currentSuitableAirport?.finalReserve = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "IcingConditionFuel":
                currentSuitableAirport?.icingConditionFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "CriticalFuel":
                currentSuitableAirport?.criticalFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "AverageWindComponent":
                currentSuitableAirport?.averageWindComponent = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
            case "AverageTemperature":
                currentSuitableAirport?.averageTemperature = ARINCTemperature(value: text.toDouble ?? 0, unit: unit)
            default:
                break
            }
        } else if inAdequateAirport {
            // Values within AdequateAirport context
            if inTerrainAvoidance {
                switch p {
                case "MaximumTerrainElevation":
                    currentAdequateAirport?.maximumTerrainElevation = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
                case "MinimumVerticalClearance":
                    currentAdequateAirport?.minimumVerticalClearance = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
                default:
                    break
                }
                return
            }
            switch p {
            case "RemainingFlightTime":
                currentAdequateAirport?.remainingFlightTime = ARINC633Duration(from: text)
            case "RemainingAirDistance":
                currentAdequateAirport?.remainingAirDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "RemainingGroundDistance":
                currentAdequateAirport?.remainingGroundDistance = ARINCDistance(value: text.toDouble ?? 0, unit: unit)
            case "Altitude":
                let rawValue = text.toDouble ?? 0
                currentAdequateAirport?.altitude = ARINCDistance(value: rawValue, unit: unit.isEmpty ? "ft" : unit)
            case "TripFuel":
                currentAdequateAirport?.tripFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "FinalReserve":
                currentAdequateAirport?.finalReserve = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "IcingConditionFuel":
                currentAdequateAirport?.icingConditionFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "CriticalFuel":
                currentAdequateAirport?.criticalFuel = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "AverageWindComponent":
                currentAdequateAirport?.averageWindComponent = ARINCSpeed(value: text.toDouble ?? 0, unit: unit)
            default:
                break
            }
        } else if currentCriticalPosition != nil {
            // Values within CriticalPosition context (outside SuitableAirport/AdequateAirport)
            switch p {
            case "CriticalTime":
                currentCriticalPosition?.criticalTime = ARINC633Duration(from: text)
            case "FuelOnBoard":
                currentCriticalPosition?.fuelOnBoard = ARINCWeight(value: text.toDouble ?? 0, unit: unit)
            case "Altitude":
                currentCriticalPosition?.altitude = ARINCAltitude(value: text.toDouble ?? 0, unit: unit.isEmpty ? "ft" : unit)
            default:
                break
            }
        }
    }

    // MARK: - Airport ICAO Code Handling

    private func handleAirportICAOCode(_ text: String) {
        if inAdequateAirport {
            currentAdequateAirport?.airportICAO = text
            return
        }
        if inSuitableAirport {
            currentSuitableAirport?.airportICAO = text
            return
        }
        if currentSection == .airportDataList {
            currentAirportData?.airportICAO = text
        } else if currentSection == .alternateRoutes && !inWaypoint {
            currentAlternateRoute?.airportICAO = text
        } else if currentSection == .contingencySaving || currentSection == .contingencySavingFuelHeader {
            if stackContains("ContingencySavingAirport") {
                contingencySaving.airportICAO = text
            } else if inContingencyAlternateFuel {
                contingencyAlternateFuel.airportICAO = text
            }
        } else if inAlternateFuel && currentSection == .fuelHeader {
            currentAlternateFuel.airportICAO = text
        } else if !inWaypoint {
            // Supplementary header
            if stackContains("DepartureAirport") {
                let existing = flightPlan.supplementaryHeader.flight
                let dept = ARINCHeaderAirport(
                    icaoCode: text,
                    iataCode: existing.departure.iataCode,
                    name: existing.departure.name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: dept,
                        arrival: existing.arrival,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            } else if stackContains("ArrivalAirport") {
                let existing = flightPlan.supplementaryHeader.flight
                let arr = ARINCHeaderAirport(
                    icaoCode: text,
                    iataCode: existing.arrival.iataCode,
                    name: existing.arrival.name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: existing.departure,
                        arrival: arr,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }
        }
    }

    // MARK: - Airport IATA Code Handling

    private func handleAirportIATACode(_ text: String) {
        if inAdequateAirport {
            currentAdequateAirport?.airportIATA = text
            return
        }
        if inSuitableAirport {
            currentSuitableAirport?.airportIATA = text
            return
        }
        if currentSection == .airportDataList {
            currentAirportData?.airportIATA = text
        } else if currentSection == .alternateRoutes && !inWaypoint {
            // Alternate route IATA
        } else if !inWaypoint && (currentSection == .none || currentSection == .flightInfo || currentSection == .remarks) {
            // Supplementary header
            if stackContains("DepartureAirport") {
                let existing = flightPlan.supplementaryHeader.flight
                let dept = ARINCHeaderAirport(
                    icaoCode: existing.departure.icaoCode,
                    iataCode: text,
                    name: existing.departure.name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: dept,
                        arrival: existing.arrival,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            } else if stackContains("ArrivalAirport") {
                let existing = flightPlan.supplementaryHeader.flight
                let arr = ARINCHeaderAirport(
                    icaoCode: existing.arrival.icaoCode,
                    iataCode: text,
                    name: existing.arrival.name
                )
                flightPlan.supplementaryHeader = SupplementaryHeader(
                    flight: ARINCHeaderFlight(
                        airlineCode: existing.airlineCode,
                        flightNumber: existing.flightNumber,
                        flightIdentifier: existing.flightIdentifier,
                        commercialFlightNumber: existing.commercialFlightNumber,
                        departure: existing.departure,
                        arrival: arr,
                        scheduledDepartureTime: existing.scheduledDepartureTime,
                        flightOriginDate: existing.flightOriginDate
                    ),
                    aircraft: flightPlan.supplementaryHeader.aircraft
                )
            }
        }
    }
}
