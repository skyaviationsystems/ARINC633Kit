// ATISTests.swift
// ARINC633KitTests
//
// Synthetic ATIS fixtures — fictional airports, no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("ATIS")
struct ATISTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <ATIS xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <ATISBulletins>
        <ATISBulletin departureType="false" informationIndicator="P" observationTime="2030-05-07T07:50:00Z" observationType="METAR" sequence="1">
          <Airport airportName="Testfield Alpha">
            <AirportICAOCode>ZZZA</AirportICAOCode>
          </Airport>
          <ATISDetails>
            <ExpectedApproaches>
              <ExpectedApproach approachType="ILS"/>
            </ExpectedApproaches>
            <Runways>
              <Runway runwayIdentifier="25L"/>
              <Runway runwayIdentifier="25R"/>
            </Runways>
            <Observation><SurfaceWinds/></Observation>
            <TransitionLevel><Value unit="ft/100">60</Value></TransitionLevel>
            <OtherEssentialOperationalInformation>TWY R11 CLOSED</OtherEssentialOperationalInformation>
          </ATISDetails>
          <ATISText><Paragraph><Text>ZZZA P METAR TEST</Text></Paragraph></ATISText>
          <ZZVendorTag custom="1"/>
        </ATISBulletin>
      </ATISBulletins>
    </ATIS>
    """.utf8)

    @Test("Parses bulletins, runways, transition level, text")
    func parsesBulletin() throws {
        guard case let .atis(atis) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .atis"); return
        }
        #expect(atis.bulletins.count == 1)
        let b = try #require(atis.bulletins.first)
        #expect(b.airportICAO == "ZZZA")
        #expect(b.airportName == "Testfield Alpha")
        #expect(b.isDeparture == false)
        #expect(b.informationIndicator == "P")
        #expect(b.observationType == "METAR")
        #expect(b.sequence == 1)
        #expect(b.expectedApproaches.first?.approachType == "ILS")
        #expect(b.runwaysInUse.map(\.runwayIdentifier) == ["25L", "25R"])
        #expect(b.transitionLevel?.value == 60)
        #expect(b.transitionLevel?.unit == "ft/100")
        #expect(b.otherEssentialOperationalInformation == "TWY R11 CLOSED")
        #expect(b.atisText == "ZZZA P METAR TEST")
        #expect(b.observation?.name == "Observation")
    }
}
