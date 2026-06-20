// NOTAMTests.swift
// ARINC633KitTests
//
// Synthetic NOTAM fixtures — fictional locations, no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("NOTAM")
struct NOTAMTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <NOTAMBriefing xmlns="http://aeec.aviation-ia.net/633" briefingType="Cockpit" creationTime="2030-01-01T00:00:00Z" fullPackage="true">
      <M633Header versionNumber="4" timestamp="2030-01-01T00:00:00Z"/>
      <NOTAM issuer="ZZZA" issuerType="ICAO" source="TEST" series="A" year="2030"
             serial="0001" startValidTime="2030-01-01T00:00:00Z" endValidTime="2030-12-31T23:59:00Z"
             endValidTimeQualifier="PERM" revisionTime="2030-01-02T00:00:00Z" sequence="3">
        <ICAONOTAMInformation qcode1="MX" qcode2="LC" trafficIndicator="IV" scope="A"/>
        <NOTAMSubjects>
          <NOTAMSubject>Runway</NOTAMSubject>
          <NOTAMSubject>Airport</NOTAMSubject>
        </NOTAMSubjects>
        <Keys>
          <Airports>
            <Airport><AirportICAOCode>ZZZA</AirportICAOCode></Airport>
            <Airport><AirportICAOCode>ZZZB</AirportICAOCode></Airport>
          </Airports>
          <Airspaces>
            <Airspace airspaceICAOCode="ZZQX"/>
            <Airspace airspaceICAOCode="ZZQM"/>
          </Airspaces>
        </Keys>
        <NOTAMText><Paragraph><Text>RWY 25L CLOSED</Text></Paragraph></NOTAMText>
      </NOTAM>
    </NOTAMBriefing>
    """.utf8)

    @Test("Subjects, multiple airports, airspaces, and qualifier attributes")
    func parsesNOTAM() throws {
        guard case let .notam(briefing) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .notam"); return
        }
        #expect(briefing.fullPackage == true)
        let n = try #require(briefing.notams.first)
        #expect(n.subjects == ["Runway", "Airport"])
        #expect(n.severity == nil)                 // no invented "sev:" severity
        #expect(n.airports == ["ZZZA", "ZZZB"])
        #expect(n.airport == "ZZZA")               // convenience = first
        #expect(n.airspaces == ["ZZQX", "ZZQM"])
        #expect(n.endValidTimeQualifier == "PERM")
        #expect(n.issuerType == "ICAO")
        #expect(n.revisionTime == "2030-01-02T00:00:00Z")
        #expect(n.sequence == 3)
        #expect(n.qcode1 == "MX")
        #expect(n.text == "RWY 25L CLOSED")
    }
}
