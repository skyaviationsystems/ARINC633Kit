// AirportDataMessageTests.swift
// ARINC633KitTests
//
// Synthetic AirportData fixtures — fictional airports, no real operational data.
//
// The parser is exercised directly via AirportDataParser().parse(data:) because the
// ARINC633 message registry still routes <AirportData> to a stub (the enum case is
// `.airportData(StubMessage)` pending rewiring).

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("AirportDataMessage")
struct AirportDataMessageTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <AirportData creationTime="2030-01-02T03:04:00" flightPlanId="OFP-TEST-1" fullPackage="true" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-01-02T03:04:00Z"/>
      <Airport sequence="1">
        <AirportIdentification airportName="Testfield Alpha">
          <AirportICAOCode>ZZZA</AirportICAOCode>
          <AirportIATACode>TFA</AirportIATACode>
        </AirportIdentification>
        <Runway runwayIdentifier="33L">
          <QFU type="magnetic" unit="deg">123.0</QFU>
          <Approach category="1" fMSProcedureName="ZAPP2" precisionApproach="true" procedureName="ZAPP">
            <RequiredHorizontalVisibility unit="m">3500.0</RequiredHorizontalVisibility>
            <RequiredVerticalVisibility unit="ft">800.0</RequiredVerticalVisibility>
          </Approach>
          <LandingDistanceAvailable unit="m">3000.0</LandingDistanceAvailable>
          <LandingThreshold><Coordinates latitude="180000.0" longitude="36000.0"/></LandingThreshold>
          <Elevation unit="m">39.624</Elevation>
          <Slope unit="deg">2.0</Slope>
          <ApprovedForRegularOperation>true</ApprovedForRegularOperation>
        </Runway>
        <Runway runwayIdentifier="15R">
          <Elevation unit="m">42.672</Elevation>
          <ApprovedForRegularOperation>false</ApprovedForRegularOperation>
        </Runway>
        <TerminalProcedures fMSProcedureName="ZSTAR3" procedureName="ZSTAR" procedureType="STAR">
          <Waypoint waypointId="ALFA1">
            <Coordinates latitude="176478.6" longitude="20709.6"/>
            <Airway type="ATS">Z123</Airway>
          </Waypoint>
          <Waypoint waypointName="TOC">
            <Coordinates latitude="170879.4" longitude="7291.2"/>
          </Waypoint>
        </TerminalProcedures>
        <MagneticVariation>15.5</MagneticVariation>
        <Elevation unit="m">44.501</Elevation>
        <AirportReferencePoint><Coordinates latitude="180000.0" longitude="-36000.0"/></AirportReferencePoint>
        <RescueAndFireFightingCategory>7</RescueAndFireFightingCategory>
        <RequiredFlightCrewQualification>B</RequiredFlightCrewQualification>
        <OpeningHours from="06:30:00" until="23:00:00"/>
        <LocalTimeOffsetToUTC positive="false">PT04H</LocalTimeOffsetToUTC>
        <ATISRadioFrequencies>
          <ATISFrequency>118.5</ATISFrequency>
          <ATISFrequency>126.2</ATISFrequency>
        </ATISRadioFrequencies>
        <ZZVendorTag custom="1"/>
      </Airport>
      <Airport>
        <AirportIdentification>
          <AirportICAOCode>ZZZB</AirportICAOCode>
        </AirportIdentification>
        <Runway runwayIdentifier="27R">
          <Elevation unit="m">3.353</Elevation>
          <ApprovedForRegularOperation>true</ApprovedForRegularOperation>
        </Runway>
      </Airport>
    </AirportData>
    """.utf8)

    @Test("Parses envelope attributes and airport count")
    func parsesEnvelope() throws {
        let msg = try AirportDataParser().parse(data: Self.xml)
        #expect(msg.flightPlanId == "OFP-TEST-1")
        #expect(msg.creationTime == "2030-01-02T03:04:00")
        #expect(msg.fullPackage == true)
        #expect(msg.header.versionNumber == "4")
        #expect(msg.airports.count == 2)
    }

    @Test("Parses airport identification, elevation and reference point")
    func parsesAirportIdentity() throws {
        let msg = try AirportDataParser().parse(data: Self.xml)
        let a = try #require(msg.airports.first)
        #expect(a.airportICAO == "ZZZA")
        #expect(a.airportIATA == "TFA")
        #expect(a.airportName == "Testfield Alpha")
        #expect(a.sequence == "1")
        #expect(a.magneticVariation == 15.5)
        #expect(a.elevation?.value == 44.501)
        #expect(a.elevation?.unit == "m")
        // 180000 arc-seconds = 50.0 deg; -36000 arc-seconds = -10.0 deg.
        #expect(a.referencePoint?.latitude == 50.0)
        #expect(a.referencePoint?.longitude == -10.0)
        #expect(a.rescueAndFireFightingCategory == 7)
        #expect(a.requiredFlightCrewQualification == "B")
        #expect(a.openingHoursFrom == "06:30:00")
        #expect(a.openingHoursUntil == "23:00:00")
        #expect(a.localTimeOffsetToUTC == "PT04H")
        #expect(a.localTimeOffsetPositive == false)
        #expect(a.atisFrequencies == [118.5, 126.2])
    }

    @Test("Parses runways, approach and units")
    func parsesRunways() throws {
        let msg = try AirportDataParser().parse(data: Self.xml)
        let a = try #require(msg.airports.first)
        #expect(a.runways.map(\.runwayIdentifier) == ["33L", "15R"])

        let rwy = try #require(a.runways.first)
        #expect(rwy.qfuMagneticTrack == 123.0)
        #expect(rwy.elevation?.value == 39.624)
        #expect(rwy.elevation?.unit == "m")
        #expect(rwy.slope == 2.0)
        #expect(rwy.approvedForRegularOperation == true)
        #expect(rwy.landingDistanceAvailable?.value == 3000.0)
        #expect(rwy.landingDistanceAvailable?.unit == "m")
        #expect(rwy.landingThreshold?.latitude == 50.0)

        let app = try #require(rwy.approaches.first)
        #expect(app.procedureName == "ZAPP")
        #expect(app.fmsProcedureName == "ZAPP2")
        #expect(app.category == "1")
        #expect(app.precisionApproach == true)
        #expect(app.requiredHorizontalVisibility?.value == 3500.0)
        #expect(app.requiredVerticalVisibility?.unit == "ft")

        #expect(a.runways.last?.approvedForRegularOperation == false)
    }

    @Test("Parses terminal procedures and waypoints")
    func parsesProcedures() throws {
        let msg = try AirportDataParser().parse(data: Self.xml)
        let a = try #require(msg.airports.first)
        let proc = try #require(a.terminalProcedures.first)
        #expect(proc.procedureName == "ZSTAR")
        #expect(proc.fmsProcedureName == "ZSTAR3")
        #expect(proc.procedureType == "STAR")
        #expect(proc.waypoints.count == 2)

        let wp = try #require(proc.waypoints.first)
        #expect(wp.waypointId == "ALFA1")
        #expect(wp.airway == "Z123")
        #expect(wp.airwayType == "ATS")
        #expect(wp.coordinates != nil)
        #expect(proc.waypoints.last?.waypointName == "TOC")
    }

    @Test("Sweeps unmodeled children into extensions")
    func capturesExtensions() throws {
        let msg = try AirportDataParser().parse(data: Self.xml)
        let a = try #require(msg.airports.first)
        #expect(a.extensions.contains { $0.name == "ZZVendorTag" })
        // Second airport with only ICAO and one runway.
        let b = try #require(msg.airports.last)
        #expect(b.airportICAO == "ZZZB")
        #expect(b.airportIATA == nil)
        #expect(b.runways.count == 1)
    }
}
