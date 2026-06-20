// RAIMReportTests.swift
// ARINC633KitTests
//
// Synthetic RAIMReport fixtures — fictional carrier/airports, fake registration/UUID,
// no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("RAIMReport")
struct RAIMReportTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <RAIMReport xmlns="http://aeec.aviation-ia.net/633" creationTime="2030-04-01T12:00:00Z" fullPackage="true">
      <M633Header versionNumber="5" timestamp="2030-04-01T12:00:00Z"/>
      <M633SupplementaryHeader>
        <Flight flightOriginDate="2030-04-01" scheduledTimeOfDeparture="2030-04-01T08:00:00Z">
          <FlightIdentification>
            <FlightIdentifier>ZZA0001</FlightIdentifier>
            <FlightNumber number="0001"/>
          </FlightIdentification>
          <DepartureAirport airportName="Testfield Alpha" airportFunction="DepartureAirport">
            <AirportICAOCode>ZZZA</AirportICAOCode>
          </DepartureAirport>
        </Flight>
        <Aircraft aircraftRegistration="ZZ-TST">
          <AircraftModel airlineSpecificSubType="T000-001"><AircraftICAOType>T000</AircraftICAOType></AircraftModel>
        </Aircraft>
        <FlightKeyIdentifier>00000000-0000-4000-8000-000000000001</FlightKeyIdentifier>
      </M633SupplementaryHeader>
      <GNSSReceiver type="999999" algorithm="FDE" sa="false" baroAiding="true" maskAngle="5"/>
      <RAIMAirportPredictions>
        <RAIMAirportPrediction outageReported="true" airportFunction="DepartureAirport">
          <Airport airportName="Testfield Alpha">
            <AirportICAOCode>ZZZA</AirportICAOCode>
          </Airport>
          <Elevation><Value unit="ft">600</Value></Elevation>
          <Coordinates latitude="173197" longitude="59651"/>
          <TimeRangeParameters begin="2030-04-01T06:00:00Z" samplePeriod="PT1M" end="2030-04-01T13:00:00Z"/>
          <RAIMParameters rnpValue="0.3" integrityLevel="RNP-AR-0.1" minimumOutage="PT1M"/>
          <RAIMOutages>
            <RAIMOutage beginOfOutage="2030-04-01T06:58:00Z" endOfOutage="2030-04-01T07:01:00Z" worstHPL="343.5" numberOfSatellites="9"/>
          </RAIMOutages>
          <SatelliteInformations>
            <SatelliteInformation GNSS="GPS" almanac="49 503808" nanus=""/>
          </SatelliteInformations>
        </RAIMAirportPrediction>
        <RAIMAirportPrediction airportFunction="ArrivalAirport">
          <Airport airportName="Testfield Bravo">
            <AirportICAOCode>ZZZB</AirportICAOCode>
          </Airport>
          <Elevation><Value unit="ft">78</Value></Elevation>
          <Coordinates latitude="100555" longitude="-55392"/>
          <RAIMParameters rnpValue="0.3" integrityLevel="TERMINAL" minimumOutage="PT5M"/>
        </RAIMAirportPrediction>
      </RAIMAirportPredictions>
      <RAIMTrajectoryPredictions>
        <RAIMTrajectoryPrediction outageReported="false" airportFunction="ArrivalAirport">
          <ADSBParameters minNic="8" minNacp="9" integrityLevel="TEST-MANDATE" minimumOutage="PT2M"/>
          <ETOScenarios>
            <ETOScenario timeScenarioOffset="PT30M">
              <Waypoint waypointId="WPTAA" waypointName="ALPHA">
                <Coordinates latitude="150000" longitude="40000"/>
                <Airway type="RNAV">A123</Airway>
                <TimeOverWaypoint>2030-04-01T09:00:00Z</TimeOverWaypoint>
                <Altitude><Value unit="ft">35000</Value></Altitude>
                <RAIMParameters rnpValue="2" integrityLevel="RNP2" minimumOutage="PT5M"/>
                <ADSBOutages>
                  <ADSBOutage beginOfOutage="2030-04-01T09:05:00Z" endOfOutage="2030-04-01T09:10:00Z" numberOfSatellites="7" worstNic="6" worstNacp="7" worstHfom="120.5"/>
                </ADSBOutages>
              </Waypoint>
            </ETOScenario>
          </ETOScenarios>
        </RAIMTrajectoryPrediction>
      </RAIMTrajectoryPredictions>
      <ZZVendorExtension custom="1"/>
    </RAIMReport>
    """.utf8)

    @Test("Parses envelope, receiver, airport predictions, outages, trajectory, extensions")
    func parsesReport() throws {
        let report = try RAIMReportParser().parse(data: Self.xml)

        // Envelope + top-level attributes.
        #expect(report.header.versionNumber == "5")
        #expect(report.supplementaryHeader.aircraft.registration == "ZZ-TST")
        #expect(report.creationTime == "2030-04-01T12:00:00Z")
        #expect(report.fullPackage == true)

        // GNSS receiver.
        let recv = try #require(report.receiver)
        #expect(recv.type == "999999")
        #expect(recv.algorithm == "FDE")
        #expect(recv.selectiveAvailability == false)
        #expect(recv.baroAiding == true)
        #expect(recv.maskAngle == 5)

        // Airport predictions.
        #expect(report.airportPredictions.count == 2)
        let a0 = try #require(report.airportPredictions.first)
        #expect(a0.airportICAO == "ZZZA")
        #expect(a0.airportName == "Testfield Alpha")
        #expect(a0.airportFunction == "DepartureAirport")
        #expect(a0.outageReported == true)
        #expect(a0.elevation?.value == 600)
        #expect(a0.elevation?.unit == "ft")
        #expect(a0.coordinates?.latitude == 173197)
        #expect(a0.coordinates?.longitude == 59651)
        #expect(a0.timeRange?.samplePeriod == "PT1M")
        #expect(a0.parameters?.integrityLevel == "RNP-AR-0.1")
        #expect(a0.parameters?.rnpValue == 0.3)
        #expect(a0.outages.count == 1)
        #expect(a0.outages.first?.worstHPL == 343.5)
        #expect(a0.outages.first?.numberOfSatellites == 9)
        #expect(a0.satelliteInformation.first?.gnss == "GPS")

        let a1 = report.airportPredictions[1]
        #expect(a1.airportICAO == "ZZZB")
        #expect(a1.outages.isEmpty)
        #expect(a1.parameters?.integrityLevel == "TERMINAL")

        // Trajectory prediction.
        #expect(report.trajectoryPredictions.count == 1)
        let t = try #require(report.trajectoryPredictions.first)
        #expect(t.outageReported == false)
        #expect(t.adsbParameters?.minNic == 8)
        #expect(t.adsbParameters?.minNacp == 9)
        #expect(t.etoScenarios.count == 1)
        let scenario = try #require(t.etoScenarios.first)
        #expect(scenario.timeScenarioOffset == "PT30M")
        let wp = try #require(scenario.waypoints.first)
        #expect(wp.waypointId == "WPTAA")
        #expect(wp.airway == "A123")
        #expect(wp.airwayType == "RNAV")
        #expect(wp.altitude?.value == 35000)
        #expect(wp.parameters?.integrityLevel == "RNP2")
        #expect(wp.adsbOutages.first?.worstHfom == 120.5)
        #expect(wp.adsbOutages.first?.numberOfSatellites == 7)

        // Unmodeled top-level child preserved, mapped children not swept in.
        #expect(report.extensions.map(\.name) == ["ZZVendorExtension"])
    }

    @Test("Backward-compatible initializer still compiles")
    func backwardCompatibleInit() {
        let report = RAIMReport(header: ARINC633Header(), supplementaryHeader: SupplementaryHeader())
        #expect(report.airportPredictions.isEmpty)
        #expect(report.receiver == nil)
    }
}
