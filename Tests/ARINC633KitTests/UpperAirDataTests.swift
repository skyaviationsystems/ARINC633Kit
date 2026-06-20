// UpperAirDataTests.swift
// ARINC633KitTests
//
// Synthetic UpperAirData fixtures — fictional flight plan, waypoints and grid values,
// no real operational meteorological data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("UpperAirData")
struct UpperAirDataTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <UpperAirData flightPlanId="FPTEST99" prognosisTime="2030-05-07T06:00:00Z" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight>
          <FlightIdentification>
            <FlightNumber airlineIATACode="ZZ" number="1"/>
          </FlightIdentification>
          <DepartureAirport><AirportICAOCode>ZZZA</AirportICAOCode></DepartureAirport>
          <ArrivalAirport><AirportICAOCode>ZZZB</AirportICAOCode></ArrivalAirport>
        </Flight>
      </M633SupplementaryHeader>
      <ObservationTimes>
        <ObservationTime prognosisValidityTime="2030-05-07T12:00:00Z">2030-05-07T06:00:00Z</ObservationTime>
        <ObservationTime prognosisValidityTime="2030-05-07T18:00:00Z">2030-05-07T06:00:00Z</ObservationTime>
      </ObservationTimes>
      <ClimbPhase>
        <AltitudeSpecificPredictedInformation>
          <Altitude><Value unit="ft/100">100</Value></Altitude>
          <WindData>
            <HorizontalWind>
              <Direction><Value type="true" unit="deg">235</Value></Direction>
              <Speed><Value unit="kt">29</Value></Speed>
            </HorizontalWind>
          </WindData>
          <TemperatureData>
            <Temperature><Value unit="C">3</Value></Temperature>
          </TemperatureData>
        </AltitudeSpecificPredictedInformation>
        <AltitudeSpecificPredictedInformation>
          <Altitude><Value unit="ft/100">200</Value></Altitude>
          <WindData>
            <HorizontalWind>
              <Direction><Value type="true" unit="deg">229</Value></Direction>
              <Speed><Value unit="kt">33</Value></Speed>
            </HorizontalWind>
          </WindData>
          <TemperatureData>
            <Temperature><Value unit="C">-17</Value></Temperature>
            <ISADeviation><Value unit="C">2</Value></ISADeviation>
          </TemperatureData>
        </AltitudeSpecificPredictedInformation>
      </ClimbPhase>
      <CruisePhase>
        <Waypoints>
          <Waypoint sequenceId="3" waypointName="TOC">
            <Coordinates latitude="180270" longitude="40476"/>
            <AltitudeSpecificPredictedInformation plannedFlightLevel="true">
              <Altitude><Value unit="ft/100">330</Value></Altitude>
              <WindData>
                <HorizontalWind>
                  <Direction><Value type="true" unit="deg">237</Value></Direction>
                  <Speed><Value unit="kt">50</Value></Speed>
                </HorizontalWind>
              </WindData>
              <TemperatureData>
                <Temperature><Value unit="C">-48</Value></Temperature>
              </TemperatureData>
            </AltitudeSpecificPredictedInformation>
            <Tropopause><Value unit="ft/100">360</Value></Tropopause>
          </Waypoint>
          <Waypoint sequenceId="4" waypointId="KULOK">
            <Coordinates latitude="180024" longitude="41868"/>
            <AltitudeSpecificPredictedInformation>
              <Altitude><Value unit="ft/100">330</Value></Altitude>
              <WindData>
                <HorizontalWind>
                  <Direction><Value type="true" unit="deg">240</Value></Direction>
                  <Speed><Value unit="kt">52</Value></Speed>
                </HorizontalWind>
              </WindData>
            </AltitudeSpecificPredictedInformation>
          </Waypoint>
        </Waypoints>
      </CruisePhase>
      <DescentPhase>
        <AltitudeSpecificPredictedInformation>
          <Altitude><Value unit="ft/100">150</Value></Altitude>
          <TemperatureData>
            <Temperature><Value unit="C">-7</Value></Temperature>
          </TemperatureData>
        </AltitudeSpecificPredictedInformation>
      </DescentPhase>
      <ZZVendorTag custom="1"/>
    </UpperAirData>
    """.utf8)

    @Test("Parses envelope, observation times, phases, waypoints and grid values")
    func parses() throws {
        let uad = try UpperAirDataParser().parse(data: Self.xml)

        // Envelope + root attributes.
        #expect(uad.header.versionNumber == "4")
        #expect(uad.flightPlanId == "FPTEST99")
        #expect(uad.prognosisTime == "2030-05-07T06:00:00Z")

        // Observation times.
        #expect(uad.observationTimes.count == 2)
        #expect(uad.observationTimes.first?.establishedTime == "2030-05-07T06:00:00Z")
        #expect(uad.observationTimes.first?.validityTime == "2030-05-07T12:00:00Z")

        // Climb phase entries (wind/temperature aloft).
        #expect(uad.climbPhase.count == 2)
        let firstClimb = try #require(uad.climbPhase.first)
        #expect(firstClimb.altitude?.value == 100)
        #expect(firstClimb.altitude?.unit == "ft/100")
        #expect(firstClimb.windDirection?.value == 235)
        #expect(firstClimb.windDirection?.unit == "deg")
        #expect(firstClimb.windSpeed?.value == 29)
        #expect(firstClimb.windSpeed?.unit == "kt")
        #expect(firstClimb.temperature?.value == 3)
        #expect(firstClimb.temperature?.unit == "C")
        #expect(uad.climbPhase[1].isaDeviation?.value == 2)

        // Cruise waypoints.
        #expect(uad.cruiseWaypoints.count == 2)
        let toc = try #require(uad.cruiseWaypoints.first)
        #expect(toc.waypointName == "TOC")
        #expect(toc.sequenceId == 3)
        // 180270 arc-seconds / 3600 = 50.075 deg N.
        let lat = try #require(toc.coordinates?.latitude)
        #expect(abs(lat - 50.075) < 0.001)
        #expect(toc.entries.count == 1)
        #expect(toc.entries.first?.plannedFlightLevel == "true")
        #expect(toc.entries.first?.windSpeed?.value == 50)
        #expect(toc.tropopause?.value == 360)
        #expect(toc.tropopause?.unit == "ft/100")
        #expect(uad.cruiseWaypoints[1].waypointId == "KULOK")

        // Descent phase.
        #expect(uad.descentPhase.count == 1)
        #expect(uad.descentPhase.first?.altitude?.value == 150)
        #expect(uad.descentPhase.first?.temperature?.value == -7)

        // Unmodeled vendor child swept into extensions.
        #expect(uad.extensions.contains { $0.name == "ZZVendorTag" })
    }
}
