// NOTAMGapsTests.swift
// ARINC633KitTests
//
// Synthetic fixtures asserting the NOTAM data-loss gap closures:
// altitude value+unit, Remark routing, extra ICAONOTAMInformation attributes /
// decoded items, additional NOTAM attributes, and the extensions bags.
// All locations are fictional — no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("NOTAM gaps")
struct NOTAMGapsTests {

    // NOTAM #1 exercises Upper/Lower bounded altitudes, a Remark, the additional
    // NOTAM attributes, the richer ICAONOTAMInformation (purpose/fIR/items), and an
    // unmodeled <VendorBlock> child that must land in this NOTAM's extensions.
    // NOTAM #2 exercises the bare repeating <Altitude> choice of AltitudeInfoType.
    // <BriefingExtension> is an unmodeled direct child of <NOTAMBriefing>.
    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <NOTAMBriefing xmlns="http://aeec.aviation-ia.net/633" briefingType="Cockpit" creationTime="2030-01-01T00:00:00Z" fullPackage="true">
      <M633Header versionNumber="4" timestamp="2030-01-01T00:00:00Z"/>
      <BriefingExtension vendor="ACME"><Note>custom</Note></BriefingExtension>
      <NOTAMs>
        <NOTAM issuer="ZZZA" issuerType="ICAO" source="TEST" series="A" year="2030"
               serial="0001" startValidTime="2030-01-01T00:00:00Z" endValidTime="2030-12-31T23:59:00Z"
               priority="1" consideredInFlightPlan="true"
               startApplicabilityTime="2030-01-01T01:00:00Z" endApplicabilityTime="2030-12-30T00:00:00Z">
          <NOTAMSubjects>
            <NOTAMSubject>Airspace</NOTAMSubject>
          </NOTAMSubjects>
          <NOTAMText><Paragraph><Text>RESTRICTED AREA ACTIVE</Text></Paragraph></NOTAMText>
          <ICAONOTAMInformation qcode1="RR" qcode2="CA" trafficIndicator="IV" scope="W"
                                purpose="BO" fIR="ZZQX" lowerAlt="0" upperAlt="100">
            <ItemA>ZZQX</ItemA>
            <ItemB>3001010100</ItemB>
            <ItemC>3012302359</ItemC>
            <ItemF>GND</ItemF>
            <ItemG>10000FT AMSL</ItemG>
          </ICAONOTAMInformation>
          <Altitudes>
            <Upper><Value unit="ft/100">100</Value></Upper>
            <Lower><Value unit="ft/100">0</Value></Lower>
          </Altitudes>
          <Remark><Paragraph><Text>OBST CLEARED WITH 2.5 GRADIENT</Text></Paragraph></Remark>
          <VendorBlock airline="ZZ"><Detail>preserve me</Detail></VendorBlock>
        </NOTAM>
        <NOTAM issuer="ZZZB" source="TEST" series="B" year="2030" serial="0002"
               startValidTime="2030-02-01T00:00:00Z" endValidTime="2030-02-02T00:00:00Z">
          <NOTAMSubjects>
            <NOTAMSubject>Waypoint</NOTAMSubject>
          </NOTAMSubjects>
          <NOTAMText><Paragraph><Text>NAV WARNING</Text></Paragraph></NOTAMText>
          <Altitudes>
            <Altitude><Value unit="ft">5000</Value></Altitude>
            <Altitude><Value unit="ft">7500</Value></Altitude>
          </Altitudes>
        </NOTAM>
      </NOTAMs>
    </NOTAMBriefing>
    """.utf8)

    private func parsed() throws -> NOTAMBriefing {
        guard case let .notam(briefing) = try ARINC633Parser().parse(data: Self.xml) else {
            throw NOTAMGapsError.wrongCase
        }
        return briefing
    }

    enum NOTAMGapsError: Error { case wrongCase }

    @Test("Altitude Upper/Lower capture value and unit (not just truncated Int)")
    func altitudeValueAndUnit() throws {
        let b = try parsed()
        let n = try #require(b.notams.first)
        let upper = try #require(n.upperAltitudeMeasured)
        #expect(upper.value == 100.0)
        #expect(upper.unit == "ft/100")
        let lower = try #require(n.lowerAltitudeMeasured)
        #expect(lower.value == 0.0)
        #expect(lower.unit == "ft/100")
        // Source-compatible Int fields still populated.
        #expect(n.upperAltitude == 100)
        #expect(n.lowerAltitude == 0)
    }

    @Test("Bare repeating <Altitude> choice captured into altitudes[]")
    func bareAltitudeChoice() throws {
        let b = try parsed()
        let n = try #require(b.notams.dropFirst().first)
        #expect(n.altitudes.count == 2)
        #expect(n.altitudes.map(\.value) == [5000.0, 7500.0])
        #expect(n.altitudes.allSatisfy { $0.unit == "ft" })
    }

    @Test("Remark routes to remark, not text")
    func remarkRouting() throws {
        let b = try parsed()
        let n = try #require(b.notams.first)
        #expect(n.text == "RESTRICTED AREA ACTIVE")
        #expect(n.remark == "OBST CLEARED WITH 2.5 GRADIENT")
        // Remark prose must not have leaked into the body text.
        #expect(!(n.text ?? "").contains("OBST"))
    }

    @Test("ICAONOTAMInformation extra attributes and decoded items captured")
    func icaoInformationExtras() throws {
        let b = try parsed()
        let n = try #require(b.notams.first)
        #expect(n.purpose == "BO")
        #expect(n.fIR == "ZZQX")
        #expect(n.lowerAlt == 0)
        #expect(n.upperAlt == 100)
        #expect(n.itemA == "ZZQX")
        #expect(n.itemB == "3001010100")
        #expect(n.itemC == "3012302359")
        #expect(n.itemF == "GND")
        #expect(n.itemG == "10000FT AMSL")
    }

    @Test("Additional NOTAM attributes captured")
    func additionalNOTAMAttributes() throws {
        let b = try parsed()
        let n = try #require(b.notams.first)
        #expect(n.priority == 1)
        #expect(n.consideredInFlightPlan == true)
        #expect(n.startApplicabilityTime == "2030-01-01T01:00:00Z")
        #expect(n.endApplicabilityTime == "2030-12-30T00:00:00Z")
    }

    @Test("Unmodeled child inside a NOTAM lands in that NOTAM's extensions")
    func notamExtensionsBag() throws {
        let b = try parsed()
        let n = try #require(b.notams.first)
        let vendor = try #require(n.extensions.first { $0.name == "VendorBlock" })
        #expect(vendor.attribute("airline") == "ZZ")
        #expect(vendor.first(named: "Detail")?.text == "preserve me")
        // Modeled children must NOT appear in the bag.
        #expect(!n.extensions.contains { $0.name == "NOTAMText" })
        #expect(!n.extensions.contains { $0.name == "Remark" })
        // Second NOTAM has no extras.
        let n2 = try #require(b.notams.dropFirst().first)
        #expect(n2.extensions.isEmpty)
    }

    @Test("Unmodeled direct child of NOTAMBriefing lands in briefing extensions")
    func briefingExtensionsBag() throws {
        let b = try parsed()
        let ext = try #require(b.extensions.first { $0.name == "BriefingExtension" })
        #expect(ext.attribute("vendor") == "ACME")
        #expect(ext.first(named: "Note")?.text == "custom")
        // Envelope children are not treated as extensions.
        #expect(!b.extensions.contains { $0.name == "M633Header" })
        #expect(!b.extensions.contains { $0.name == "NOTAMs" })
    }
}
