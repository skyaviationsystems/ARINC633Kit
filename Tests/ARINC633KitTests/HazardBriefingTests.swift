// HazardBriefingTests.swift
// ARINC633KitTests
//
// Synthetic HazardBriefing fixtures — fictional volcanoes, airspaces and coordinates,
// no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("HazardBriefing")
struct HazardBriefingTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <HazardBriefing creationTime="2030-04-01T00:00:00Z" fullPackage="true" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-04-01T00:00:05Z"/>
      <HazardAdvisories>
        <HazardAdvisory advisoryNumber="2030/001" issuer="VAAC TESTVILLE" source="ZZW"
                        observationTime="2030-04-01T00:00:00Z" startValidTime="2030-04-01T00:30:00Z"
                        endValidTime="2030-04-01T06:30:00Z" sequence="3">
          <HazardType>Volcanic Ash Cloud</HazardType>
          <Airspaces>
            <Airspace airspaceICAOCode="ZZZZ">
              <AirspaceName>TESTLAND FIR</AirspaceName>
            </Airspace>
          </Airspaces>
          <HazardousArea volcanoNumber="0000-01">
            <PlaceName areaName="TESTLAND">MOUNT SYNTHETIC</PlaceName>
            <Coordinates latitude="113700" longitude="470400"/>
            <Elevation><Value unit="m">1200</Value></Elevation>
          </HazardousArea>
          <HazardDetails>ASH VENTING TEST</HazardDetails>
          <Observation observationTime="2030-04-01T00:00:00Z">
            <Altitudes>
              <Altitude upperLowerBound="upper"><Value unit="ft/100">70</Value></Altitude>
            </Altitudes>
            <Geography>
              <Polygon>
                <Coordinates sequence="1" latitude="100" longitude="200"/>
                <Coordinates sequence="2" latitude="300" longitude="400"/>
              </Polygon>
              <MovementSpeed><Value unit="kt">10</Value></MovementSpeed>
              <MovementDirection><Value type="true" unit="deg">45</Value></MovementDirection>
            </Geography>
          </Observation>
          <Forecasts>
            <Forecast forecastTime="2030-04-01T06:00:00Z">
              <Geography>
                <Spot><Coordinates latitude="500" longitude="600"/></Spot>
              </Geography>
            </Forecast>
          </Forecasts>
          <Remark><Paragraph><Text>STNR INTST UNKNOWN</Text></Paragraph></Remark>
          <HazardAdvisoryText><Paragraph><Text>VA ADVISORY TEST</Text></Paragraph></HazardAdvisoryText>
          <ZZVendorTag custom="1"/>
        </HazardAdvisory>
      </HazardAdvisories>
    </HazardBriefing>
    """.utf8)

    @Test("Parses briefing attributes, advisory fields, area, extents and extensions")
    func parsesBriefing() throws {
        let briefing = try HazardBriefingParser().parse(data: Self.xml)

        // Top-level envelope + attributes.
        #expect(briefing.header.versionNumber == "4")
        #expect(briefing.creationTime == "2030-04-01T00:00:00Z")
        #expect(briefing.fullPackage == true)
        #expect(briefing.advisories.count == 1)

        let a = try #require(briefing.advisories.first)
        #expect(a.hazardType == "Volcanic Ash Cloud")
        #expect(a.issuer == "VAAC TESTVILLE")
        #expect(a.source == "ZZW")
        #expect(a.advisoryNumber == "2030/001")
        #expect(a.observationTime == "2030-04-01T00:00:00Z")
        #expect(a.startValidTime == "2030-04-01T00:30:00Z")
        #expect(a.endValidTime == "2030-04-01T06:30:00Z")
        #expect(a.sequence == 3)
        #expect(a.hazardDetails == "ASH VENTING TEST")
        #expect(a.remark == "STNR INTST UNKNOWN")
        #expect(a.advisoryText == "VA ADVISORY TEST")

        // Airspace.
        #expect(a.airspaces.count == 1)
        #expect(a.airspaces.first?.icaoCode == "ZZZZ")
        #expect(a.airspaces.first?.name == "TESTLAND FIR")

        // Hazardous area.
        let area = try #require(a.hazardousArea)
        #expect(area.volcanoNumber == "0000-01")
        #expect(area.placeName == "MOUNT SYNTHETIC")
        #expect(area.areaName == "TESTLAND")
        #expect(area.latitude == 113700)
        #expect(area.longitude == 470400)
        #expect(area.elevation?.value == 1200)
        #expect(area.elevation?.unit == "m")

        // Observation extent.
        let obs = try #require(a.observation)
        #expect(obs.time == "2030-04-01T00:00:00Z")
        #expect(obs.upperAltitude?.value == 70)
        #expect(obs.upperAltitude?.unit == "ft/100")
        #expect(obs.movementSpeed?.value == 10)
        #expect(obs.movementSpeed?.unit == "kt")
        #expect(obs.movementDirection == 45)
        #expect(obs.geography?.name == "Geography")

        // Forecast extent.
        #expect(a.forecasts.count == 1)
        #expect(a.forecasts.first?.time == "2030-04-01T06:00:00Z")
        #expect(a.forecasts.first?.geography?.first(named: "Spot") != nil)

        // Unmapped advisory child preserved.
        #expect(a.extensions.contains { $0.name == "ZZVendorTag" })
    }

    @Test("Backward-compatible initializer still works")
    func backwardCompatibleInit() {
        let briefing = HazardBriefing(header: ARINC633Header(versionNumber: "4", timestamp: "t"),
                                      supplementaryHeader: SupplementaryHeader())
        #expect(briefing.advisories.isEmpty)
        #expect(briefing.creationTime == nil)
        #expect(briefing.fullPackage == nil)
    }
}
