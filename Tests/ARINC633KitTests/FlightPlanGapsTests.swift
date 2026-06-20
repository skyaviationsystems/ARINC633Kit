// FlightPlanGapsTests.swift
// ARINC633KitTests
//
// Synthetic fixtures locking the FlightPlan data-loss gap-closures:
//   1. Actual* values resolve via EstimatedActual.actual
//   2. Summary-level ETOPSSummary/AdequateAirports parsed
//   3. PossibleExtra distinct from MaximumFuelWeight (+ density)
//   4. New fuel lines (NoAlternateFinalReserve, ETOPSFuel, ...)
//   5. Protected vs Unprotected extra-fuel flag
//   6. Per-waypoint extras (AircraftWeight, LeakDetection, ...)
//   7. ContingencyPolicy/EnrouteAlternateAirport ICAO
//   8. Unknown top-level children land in FlightPlan.extensions
//
// All XML below is SYNTHETIC (no verbatim spec content).

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("FlightPlan gaps")
struct FlightPlanGapsTests {

    private func parse(_ xml: String) throws -> FlightPlan {
        guard case let .flightPlan(plan) = try ARINC633Parser().parse(data: Data(xml.utf8)) else {
            throw ARINC633ParseError.emptyDocument
        }
        return plan
    }

    // MARK: - Item 1: Actual* resolves via .actual

    @Test("Per-waypoint ActualWeight/ActualAltitude populate the .actual side and resolve")
    func actualResolves() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <Waypoints>
            <Waypoint waypointId="ALFA" sequenceId="1">
              <Altitude>
                <EstimatedAltitude><Value unit="ft">35000</Value></EstimatedAltitude>
                <ActualAltitude><Value unit="ft">34800</Value></ActualAltitude>
              </Altitude>
              <FuelOnBoard>
                <EstimatedWeight><Value unit="kg">50000</Value></EstimatedWeight>
                <ActualWeight><Value unit="kg">49500</Value></ActualWeight>
              </FuelOnBoard>
            </Waypoint>
          </Waypoints>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let wp = try #require(plan.waypoints.first)
        #expect(wp.altitude.actual?.value == 34800)
        #expect(wp.altitude.resolved?.value == 34800)   // actual preferred over estimated
        #expect(wp.fuelOnBoard.actual?.value == 49500)
        #expect(wp.fuelOnBoard.resolved?.value == 49500)
    }

    // MARK: - Item 2: Summary-level AdequateAirports

    @Test("ETOPSSummary/AdequateAirports parsed with full ICAO/IATA/name")
    func summaryAdequateAirports() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <ETOPSSummary ruleTime="PT3H00M00S" borderTime="PT1H">
            <CriticalPositions/>
            <AdequateAirports>
              <AdequateAirport airportName="ALPHA INTL" airportFunction="ETOPSAdequateAirport">
                <AirportICAOCode>AAAA</AirportICAOCode>
                <AirportIATACode>AAA</AirportIATACode>
              </AdequateAirport>
              <AdequateAirport airportName="BRAVO INTL" airportFunction="ETOPSAdequateAirport">
                <AirportICAOCode>BBBB</AirportICAOCode>
                <AirportIATACode>BBB</AirportIATACode>
              </AdequateAirport>
            </AdequateAirports>
          </ETOPSSummary>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let etops = try #require(plan.etopsSummary)
        #expect(etops.summaryAdequateAirports.count == 2)
        #expect(etops.summaryAdequateAirports.first?.airportICAO == "AAAA")
        #expect(etops.summaryAdequateAirports.first?.airportIATA == "AAA")
        #expect(etops.summaryAdequateAirports.first?.airportName == "ALPHA INTL")
        #expect(etops.summaryAdequateAirports.last?.airportICAO == "BBBB")
        // Legacy [String] list mirrors the ICAO codes.
        #expect(etops.adequateAirports == ["AAAA", "BBBB"])
    }

    // MARK: - Item 3: PossibleExtra distinct from MaximumFuelWeight

    @Test("PossibleExtra and MaximumFuelWeight map to distinct fields, density captured")
    func possibleExtraDistinct() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <FuelHeader>
            <PossibleExtraFuel reason="L">
              <PossibleExtra><Value unit="kg">5000</Value></PossibleExtra>
              <MaximumFuelWeight>
                <Weight><Value unit="kg">17000</Value></Weight>
                <Density><Value unit="g/cm3">0.8</Value></Density>
              </MaximumFuelWeight>
              <TankVolume><Value unit="l">21000</Value></TankVolume>
            </PossibleExtraFuel>
          </FuelHeader>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let fh = try #require(plan.fuelHeader)
        #expect(fh.possibleExtraFuelWeight?.value == 5000)     // loadable extra
        #expect(fh.maxExtraFuelWeight?.value == 17000)         // tank capacity
        #expect(fh.possibleExtraFuelWeight?.value != fh.maxExtraFuelWeight?.value)
        #expect(fh.maximumFuelDensity?.value == 0.8)
        #expect(fh.maximumFuelDensity?.unit == "g/cm3")
        #expect(fh.tankVolume?.value == 21000)
    }

    // MARK: - Item 4: New fuel lines

    @Test("NoAlternateFinalReserve and ETOPSFuel fuel lines captured (weight + duration)")
    func newFuelLines() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <FuelHeader>
            <NoAlternateFinalReserve>
              <EstimatedWeight><Value unit="kg">504</Value></EstimatedWeight>
              <Duration><Value>PT15M</Value></Duration>
            </NoAlternateFinalReserve>
            <ETOPSFuel>
              <EstimatedWeight><Value unit="kg">1200</Value></EstimatedWeight>
              <Duration><Value>PT20M</Value></Duration>
            </ETOPSFuel>
            <BlockFuel>
              <EstimatedWeight><Value unit="kg">90000</Value></EstimatedWeight>
              <FuelOnBoardAfterRefueling><Value unit="kg">91000</Value></FuelOnBoardAfterRefueling>
            </BlockFuel>
          </FuelHeader>
          <NonStandardFlightPlanningType>
            <NoAlternate>true</NoAlternate>
          </NonStandardFlightPlanningType>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let fh = try #require(plan.fuelHeader)
        #expect(fh.noAlternateFinalReserveFuel?.value == 504)
        #expect(fh.noAlternateFinalReserveDuration != nil)
        #expect(fh.etopsFuel?.value == 1200)
        #expect(fh.etopsDuration != nil)
        #expect(fh.fuelOnBoardAfterRefueling?.value == 91000)
        #expect(fh.blockFuel?.value == 90000)
        #expect(fh.noAlternate == true)
    }

    // MARK: - Item 5: Protected vs Unprotected extra fuel

    @Test("ProtectedExtraFuels / UnprotectedExtraFuels set the protected flag")
    func protectedExtraFlag() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <FuelHeader>
            <ProtectedExtraFuels>
              <ExtraFuel reason="Extra">
                <EstimatedWeight><Value unit="kg">300</Value></EstimatedWeight>
                <Duration><Value>PT5M</Value></Duration>
              </ExtraFuel>
            </ProtectedExtraFuels>
            <UnprotectedExtraFuels>
              <ExtraFuel reason="DEV">
                <EstimatedWeight><Value unit="kg">100</Value></EstimatedWeight>
                <Duration><Value>PT2M</Value></Duration>
              </ExtraFuel>
            </UnprotectedExtraFuels>
          </FuelHeader>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let fh = try #require(plan.fuelHeader)
        #expect(fh.extraFuels.count == 2)
        let protectedItem = fh.extraFuels.first { $0.protected == true }
        let unprotectedItem = fh.extraFuels.first { $0.protected == false }
        #expect(protectedItem?.weight?.value == 300)
        #expect(unprotectedItem?.weight?.value == 100)
    }

    // MARK: - Item 6: Per-waypoint extras

    @Test("Per-waypoint AircraftWeight and LeakDetection captured with units")
    func waypointExtras() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <Waypoints>
            <Waypoint waypointId="ALFA" sequenceId="1">
              <AircraftWeight>
                <EstimatedWeight><Value unit="kg">313775</Value></EstimatedWeight>
                <ActualWeight><Value unit="kg">313000</Value></ActualWeight>
              </AircraftWeight>
              <CalculatedFuelOnBoard><Value unit="kg">42000</Value></CalculatedFuelOnBoard>
              <FuelOnBoardDifference><Value unit="kg">-50</Value></FuelOnBoardDifference>
              <CumulatedBurnOffDifference><Value unit="kg">30</Value></CumulatedBurnOffDifference>
              <LeakDetection><Value unit="kg">-20</Value></LeakDetection>
              <SegmentCrossWindComponent><Value unit="kt">12</Value></SegmentCrossWindComponent>
              <SegmentShearRate>
                <SegmentVerticalWindChange><Value unit="m/s">3</Value></SegmentVerticalWindChange>
              </SegmentShearRate>
            </Waypoint>
          </Waypoints>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let wp = try #require(plan.waypoints.first)
        #expect(wp.aircraftWeight.estimated?.value == 313775)
        #expect(wp.aircraftWeight.actual?.value == 313000)
        #expect(wp.aircraftWeight.estimated?.unit == "kg")
        #expect(wp.calculatedFuelOnBoard?.value == 42000)
        #expect(wp.fuelOnBoardDifference?.value == -50)
        #expect(wp.cumulatedBurnOffDifference?.value == 30)
        #expect(wp.leakDetection?.value == -20)             // safety-relevant leak indicator
        #expect(wp.segmentCrossWindComponent?.value == 12)
        #expect(wp.segmentShearRate?.value == 3)
    }

    // MARK: - Item 7: EnrouteAlternateAirport ICAO

    @Test("ContingencyFuel/ContingencyPolicy/EnrouteAlternateAirport ICAO captured")
    func enrouteAlternateICAO() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <FuelHeader>
            <ContingencyFuel>
              <EstimatedWeight><Value unit="kg">1500</Value></EstimatedWeight>
              <ContingencyPolicy policyName="3% + ERA">
                <EnrouteAlternateAirport>
                  <AirportICAOCode>EDDF</AirportICAOCode>
                </EnrouteAlternateAirport>
              </ContingencyPolicy>
            </ContingencyFuel>
          </FuelHeader>
        </FlightPlan>
        """
        let plan = try parse(xml)
        let fh = try #require(plan.fuelHeader)
        #expect(fh.contingencyPolicy == "3% + ERA")
        #expect(fh.contingencyEnrouteAlternateAirportICAO == "EDDF")
        #expect(fh.contingencyFuel?.value == 1500)
    }

    // MARK: - Item 8: Extensions bag

    @Test("Unknown top-level child is preserved in FlightPlan.extensions")
    func extensionsBag() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
          <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
          <FuelHeader>
            <BlockFuel><EstimatedWeight><Value unit="kg">90000</Value></EstimatedWeight></BlockFuel>
          </FuelHeader>
          <AirlineVendorExtension foo="bar">
            <CustomValue>42</CustomValue>
          </AirlineVendorExtension>
        </FlightPlan>
        """
        let plan = try parse(xml)
        // Modeled section still parsed.
        #expect(plan.fuelHeader?.blockFuel?.value == 90000)
        // Unknown sibling preserved verbatim.
        let ext = try #require(plan.extensions.first { $0.name == "AirlineVendorExtension" })
        #expect(ext.attribute("foo") == "bar")
        #expect(ext.firstDescendant(named: "CustomValue")?.text == "42")
        // Known sections are NOT swept into extensions.
        #expect(!plan.extensions.contains { $0.name == "FuelHeader" })
        #expect(!plan.extensions.contains { $0.name == "M633Header" })
    }
}
