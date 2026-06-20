// PIREPBriefingTests.swift
// ARINC633KitTests
//
// Synthetic PIREPBriefing fixtures — fictional carrier and airports, no real
// operational data. All ICAO/IATA codes, coordinates, and times are invented.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("PIREPBriefing")
struct PIREPBriefingTests {

    // Two synthetic pilot reports: an icing report located by geographic spot, and a
    // braking-action report located by airport + runway. Includes a vendor extension
    // child to exercise the extensions bag.
    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <PIREPBriefing creationTime="2030-04-01T12:00:00Z" fullPackage="true" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-04-01T11:59:30Z"/>
      <PIREPs>
        <PIREP observationTime="2030-04-01T11:50:00Z" source="ZZA" issuer="ZZA" priority="2" sequence="1">
          <PirepText>
            <Paragraph>
              <Text>Light clear ice reported in cruise. ZZZ123</Text>
            </Paragraph>
          </PirepText>
          <Location>
            <Geography>
              <Spot>
                <Coordinates latitude="180000" longitude="64800"/>
                <Radius><Value unit="NM">15</Value></Radius>
              </Spot>
            </Geography>
          </Location>
          <Altitudes>
            <Altitude><Value unit="ft/100">350</Value></Altitude>
          </Altitudes>
          <DecodedInformation>
            <Icing icingType="clear ice" intensity="light">
              <IndicatedAirSpeed><Value unit="kt">300</Value></IndicatedAirSpeed>
              <Temperatures>
                <StaticAirTemperature><Value unit="C">-15</Value></StaticAirTemperature>
              </Temperatures>
            </Icing>
          </DecodedInformation>
          <AircraftICAOType>A320</AircraftICAOType>
          <ZZVendorTag custom="1"/>
        </PIREP>
        <PIREP observationTime="2030-04-01T11:45:00Z" issuer="ZZB">
          <PirepText>
            <Paragraph>
              <Text>RWY 25R wet, braking action medium to poor. ZZ456</Text>
            </Paragraph>
          </PirepText>
          <Location>
            <Airspaces>
              <Airspace airspaceICAOCode="ZZZX"><AirspaceName>Testfield Control</AirspaceName></Airspace>
            </Airspaces>
            <Airport>
              <AirportICAOCode>ZZZA</AirportICAOCode>
              <Runways>
                <Runway runwayIdentifier="25R"/>
              </Runways>
            </Airport>
          </Location>
          <DecodedInformation>
            <BrakingAction>medium to poor</BrakingAction>
          </DecodedInformation>
        </PIREP>
      </PIREPs>
    </PIREPBriefing>
    """.utf8)

    @Test("Parses briefing attributes, header, and PIREP count")
    func parsesBriefingEnvelope() throws {
        guard case let .pirepBriefing(briefing) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .pirepBriefing"); return
        }
        #expect(briefing.creationTime == "2030-04-01T12:00:00Z")
        #expect(briefing.fullPackage == true)
        #expect(briefing.header.versionNumber == "4")
        #expect(briefing.pireps.count == 2)
    }

    @Test("Parses icing PIREP with spot location, altitude, and decoded info")
    func parsesIcingReport() throws {
        guard case let .pirepBriefing(briefing) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .pirepBriefing"); return
        }
        let p = try #require(briefing.pireps.first)
        #expect(p.issuer == "ZZA")
        #expect(p.source == "ZZA")
        #expect(p.observationTime == "2030-04-01T11:50:00Z")
        #expect(p.priority == 2)
        #expect(p.sequence == 1)
        #expect(p.pirepText == "Light clear ice reported in cruise. ZZZ123")
        #expect(p.aircraftICAOType == "A320")

        // Spot location: 180000 arc-seconds latitude => 50.0 degrees.
        let spot = try #require(p.location.geography?.spot)
        #expect(spot.latitudeArcSeconds == "180000")
        #expect(spot.coordinate?.latitude == 50.0)
        #expect(spot.coordinate?.longitude == 18.0)
        #expect(spot.radius?.value == 15)
        #expect(spot.radius?.unit == "NM")

        // Altitude.
        #expect(p.altitudes?.altitudes.first?.value == 350)
        #expect(p.altitudes?.altitudes.first?.unit == "ft/100")

        // Decoded icing.
        let icing = try #require(p.decoded?.icing)
        #expect(icing.icingType == "clear ice")
        #expect(icing.intensity == "light")
        #expect(icing.indicatedAirSpeed?.value == 300)
        #expect(icing.staticAirTemperature?.value == -15)
        #expect(icing.staticAirTemperature?.unit == "C")

        // Vendor extension preserved.
        #expect(p.extensions.contains { $0.name == "ZZVendorTag" })
    }

    @Test("Parses airport/runway location, airspace, and braking action")
    func parsesBrakingActionReport() throws {
        guard case let .pirepBriefing(briefing) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .pirepBriefing"); return
        }
        let p = try #require(briefing.pireps.last)
        #expect(p.issuer == "ZZB")
        #expect(p.location.airport?.icaoCode == "ZZZA")
        #expect(p.location.airport?.runways == ["25R"])
        #expect(p.location.airspaces.first?.icaoCode == "ZZZX")
        #expect(p.location.airspaces.first?.name == "Testfield Control")
        #expect(p.decoded?.brakingAction == "medium to poor")
    }
}
