// RegionWeatherTests.swift
// ARINC633KitTests
//
// Synthetic RegionWeatherBriefing fixtures — fictional airspaces, codes, and
// coordinates; no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("RegionWeather")
struct RegionWeatherTests {

    // A two-bulletin briefing exercising attributes, text, airspaces, a movement
    // vector, polygon coordinates, altitude band, decoded turbulence, a remark, and a
    // vendor extension element.
    private static let briefingXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <RegionWeatherBriefing xmlns="http://aeec.aviation-ia.net/633"
                           creationTime="2030-08-02T15:52:59Z" fullPackage="true">
      <M633Header versionNumber="4" timestamp="2030-08-09T15:45:39Z"/>
      <RegionWeathers>
        <RegionWeather issuer="ZZZX" source="TESTWX" type="SIGMET"
                       startValidTime="2030-08-08T07:00:00Z"
                       endValidTime="2030-08-08T11:00:00Z"
                       observationTime="2030-08-08T07:00:00Z" priority="2" sequence="1">
          <RegionWeatherText><Paragraph sequence="1"><Text>ALPHA 1 VALID TEST FRQ TS TOP FL500</Text></Paragraph></RegionWeatherText>
          <Location>
            <Airspaces>
              <Airspace airspaceICAOCode="ZZZX"><AirspaceName>Test Oceanic FIR</AirspaceName></Airspace>
            </Airspaces>
            <Geography>
              <Polygon>
                <Coordinates sequence="1" latitude="73800" longitude="-196200"/>
                <Coordinates sequence="2" latitude="65700" longitude="-186300"/>
                <Coordinates sequence="3" latitude="73800" longitude="-196200"/>
              </Polygon>
              <MovementSpeed><Value unit="kt">20</Value></MovementSpeed>
              <MovementDirection><Value type="true" unit="deg">45</Value></MovementDirection>
            </Geography>
          </Location>
          <Altitudes>
            <Upper><Value unit="ft/100">500</Value></Upper>
            <Lower><Value unit="ft/100">100</Value></Lower>
          </Altitudes>
          <DecodedInformation>
            <Turbulence turbulenceType="clear air" intensity="severe" edr="0.6"/>
            <Thunderstorm><Trend>developing</Trend></Thunderstorm>
          </DecodedInformation>
          <Remark><Text>SYNTHETIC REMARK</Text></Remark>
          <ZZVendorTag custom="1"/>
        </RegionWeather>
        <RegionWeather issuer="ZZZX" source="TESTWX" type="AIRMET"
                       observationTime="2030-08-08T09:15:00Z" sequence="2">
          <RegionWeatherText><Paragraph sequence="1"><Text>BRAVO 1 VALID TEST</Text></Paragraph></RegionWeatherText>
        </RegionWeather>
      </RegionWeathers>
    </RegionWeatherBriefing>
    """.utf8)

    // A bare <RegionWeather> root (the second supported root), one bulletin.
    private static let bareXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <RegionWeather xmlns="http://aeec.aviation-ia.net/633"
                   issuer="ZZZY" source="TESTWX" type="CONVECTIVE SIGMET"
                   observationTime="2030-08-08T07:00:00Z" sequence="9">
      <M633Header versionNumber="4" timestamp="2030-08-08T07:00:00Z"/>
      <RegionWeatherText><Text>CHARLIE 1 VALID TEST</Text></RegionWeatherText>
    </RegionWeather>
    """.utf8)

    @Test("Parses full briefing: attributes, bulletins, geography, altitudes, decoded")
    func parsesBriefing() throws {
        let briefing = try RegionWeatherParser().parse(data: Self.briefingXML)

        #expect(briefing.creationTime == "2030-08-02T15:52:59Z")
        #expect(briefing.fullPackage == true)
        #expect(briefing.header.versionNumber == "4")
        #expect(briefing.regions.count == 2)

        let r = try #require(briefing.regions.first)
        #expect(r.issuer == "ZZZX")
        #expect(r.source == "TESTWX")
        #expect(r.type == "SIGMET")
        #expect(r.startValidTime == "2030-08-08T07:00:00Z")
        #expect(r.observationTime == "2030-08-08T07:00:00Z")
        #expect(r.priority == 2)
        #expect(r.sequence == 1)
        #expect(r.text == "ALPHA 1 VALID TEST FRQ TS TOP FL500")
        #expect(r.remark == "SYNTHETIC REMARK")

        // Location / airspaces.
        let loc = try #require(r.location)
        #expect(loc.airspaces.count == 1)
        #expect(loc.airspaces.first?.icaoCode == "ZZZX")
        #expect(loc.airspaces.first?.name == "Test Oceanic FIR")

        // Geography polygon + movement vector.
        let geo = try #require(loc.geography)
        let poly = try #require(geo.polygon)
        #expect(poly.coordinates.count == 3)
        #expect(poly.coordinates.first?.sequence == 1)
        // 73800 arc-seconds / 3600 = 20.5 deg
        #expect(poly.coordinates.first?.coordinate?.latitude == 20.5)
        #expect(geo.movementSpeed?.value == 20)
        #expect(geo.movementSpeed?.unit == "kt")
        #expect(geo.movementDirection?.value == 45)

        // Altitudes band.
        let alt = try #require(r.altitudes)
        #expect(alt.upper?.value == 500)
        #expect(alt.lower?.value == 100)
        #expect(alt.lower?.unit == "ft/100")

        // Decoded turbulence + thunderstorm trend.
        let dec = try #require(r.decoded)
        #expect(dec.turbulence?.intensity == "severe")
        #expect(dec.turbulence?.turbulenceType == "clear air")
        #expect(dec.turbulence?.edr == 0.6)
        #expect(dec.thunderstormTrend == "developing")

        // Unmapped child preserved.
        #expect(r.extensions.contains { $0.name == "ZZVendorTag" })

        // Second bulletin (minimal).
        let r2 = try #require(briefing.regions.last)
        #expect(r2.type == "AIRMET")
        #expect(r2.sequence == 2)
        #expect(r2.text == "BRAVO 1 VALID TEST")
        #expect(r2.location == nil)
    }

    @Test("Parses a bare <RegionWeather> root as a single-bulletin briefing")
    func parsesBareRoot() throws {
        let briefing = try RegionWeatherParser().parse(data: Self.bareXML)

        #expect(briefing.regions.count == 1)
        let r = try #require(briefing.regions.first)
        #expect(r.issuer == "ZZZY")
        #expect(r.type == "CONVECTIVE SIGMET")
        #expect(r.sequence == 9)
        #expect(r.text == "CHARLIE 1 VALID TEST")
    }
}
