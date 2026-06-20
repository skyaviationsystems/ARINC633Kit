// DeIcingTests.swift
// ARINC633KitTests
//
// Synthetic DeIcing fixtures — fictional flights/airports/providers, no real
// operational data. Exercises DeIcingParser directly (registry not yet rewired).

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("DeIcing")
struct DeIcingTests {

    // MARK: - DORSUB (De-Icing Order Submit)

    private static let dorsub = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <DORSUB xmlns="http://aeec.aviation-ia.net/633" deicingRequiredIndicator="true" acknowledgementRequired="true">
      <M633Header versionNumber="4" timestamp="2030-12-01T05:00:00Z"/>
      <M633SupplementaryHeader/>
      <ServiceAirport>ZZZA</ServiceAirport>
      <DeIcingProviderID>ABC</DeIcingProviderID>
      <ServiceFlight>9001</ServiceFlight>
      <ZZVendorTag custom="1"/>
    </DORSUB>
    """.utf8)

    @Test("DORSUB: subtype, order routing, attributes, extensions")
    func parsesDORSUB() throws {
        let m = try DeIcingParser().parse(data: Self.dorsub)
        #expect(m.messageSubtype == "DORSUB")
        #expect(m.serviceAirport == "ZZZA")
        #expect(m.deIcingProviderID == "ABC")
        #expect(m.serviceFlight == "9001")
        #expect(m.deicingRequired == true)
        #expect(m.acknowledgementRequired == true)
        #expect(m.header.versionNumber == "4")
        #expect(m.treatment == nil)
        #expect(m.extensions.map(\.name) == ["ZZVendorTag"])
    }

    // MARK: - DORIND (De-Icing Order Indication)

    private static let dorind = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <DORIND xmlns="http://aeec.aviation-ia.net/633" deIcingOpsIndicator="adverse">
      <M633Header versionNumber="4" timestamp="2030-12-01T05:10:00Z"/>
      <M633SupplementaryHeader/>
      <DeIcingPlace deIcingPlaceType="at Pad (remote)">PAD7</DeIcingPlace>
      <EstimatedDe-IcingBeginTime>2030-12-01T05:30:00Z</EstimatedDe-IcingBeginTime>
      <EstimatedDe-IcingEndTime>2030-12-01T05:45:00Z</EstimatedDe-IcingEndTime>
      <DeIcingSequenceNumber>3</DeIcingSequenceNumber>
      <Remark><Paragraph><Text>HOLDOVER ADVISORY</Text></Paragraph></Remark>
    </DORIND>
    """.utf8)

    @Test("DORIND: place, estimated times, sequence, ops indicator, remark")
    func parsesDORIND() throws {
        let m = try DeIcingParser().parse(data: Self.dorind)
        #expect(m.messageSubtype == "DORIND")
        #expect(m.deIcingPlace == "PAD7")
        #expect(m.deIcingPlaceType == "at Pad (remote)")
        #expect(m.estimatedBeginTime == "2030-12-01T05:30:00Z")
        #expect(m.estimatedEndTime == "2030-12-01T05:45:00Z")
        #expect(m.deIcingSequenceNumber == 3)
        #expect(m.deIcingOpsIndicator == "adverse")
        #expect(m.remark == "HOLDOVER ADVISORY")
    }

    // MARK: - DPRREP (De-Icing Process Report, AntiIcing branch)

    private static let dprrep = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <DPRREP xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-12-01T06:00:00Z"/>
      <M633SupplementaryHeader/>
      <AntiIcing>
        <DeIcingFluidType>2</DeIcingFluidType>
        <DeIcingFluidMix>75</DeIcingFluidMix>
        <ActualDeIcingBeginTime>2030-12-01T05:50:00Z</ActualDeIcingBeginTime>
        <ActualDeIcingEndTime>2030-12-01T05:55:00Z</ActualDeIcingEndTime>
        <AntiIcingCode>
          <AntiIcingFluidType>4</AntiIcingFluidType>
          <AntiIcingFluidMix>100</AntiIcingFluidMix>
          <ActualAntiIcingBeginTime>2030-12-01T05:56:00Z</ActualAntiIcingBeginTime>
        </AntiIcingCode>
        <ActualAntiIcingEndTime>2030-12-01T06:00:00Z</ActualAntiIcingEndTime>
      </AntiIcing>
      <Remark><Paragraph><Text>TYPE IV APPLIED</Text></Paragraph></Remark>
    </DPRREP>
    """.utf8)

    @Test("DPRREP: anti-icing treatment de-icing + anti-icing groups")
    func parsesDPRREP() throws {
        let m = try DeIcingParser().parse(data: Self.dprrep)
        #expect(m.messageSubtype == "DPRREP")
        let t = try #require(m.treatment)
        #expect(t.isAntiIcing == true)
        #expect(t.deIcingFluidType == 2)
        #expect(t.deIcingFluidMix == 75)
        #expect(t.actualDeIcingBeginTime == "2030-12-01T05:50:00Z")
        #expect(t.actualDeIcingEndTime == "2030-12-01T05:55:00Z")
        #expect(t.antiIcingFluidType == 4)
        #expect(t.antiIcingFluidMix == 100)
        #expect(t.actualAntiIcingBeginTime == "2030-12-01T05:56:00Z")
        #expect(t.actualAntiIcingEndTime == "2030-12-01T06:00:00Z")
        #expect(m.remark == "TYPE IV APPLIED")
    }

    // MARK: - DRCSUB (De-Icing Receipt Submit, with fluid volumes)

    private static let drcsub = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <DRCSUB xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-12-01T06:30:00Z"/>
      <M633SupplementaryHeader/>
      <DeIcingProviderId>XYZ</DeIcingProviderId>
      <DeIcingReceiptNumber>RCPT-0042</DeIcingReceiptNumber>
      <AntiIcing>
        <DeIcingFluidType>1</DeIcingFluidType>
        <DeIcingFluidMix>50</DeIcingFluidMix>
        <DeIcingFluidVolume unit="l">120</DeIcingFluidVolume>
        <AntiIcingCode>
          <AntiIcingFluidType>4</AntiIcingFluidType>
          <ActualAntiIcingBeginTime>2030-12-01T06:20:00Z</ActualAntiIcingBeginTime>
        </AntiIcingCode>
        <AntiIcingFluidVolume unit="l">40</AntiIcingFluidVolume>
      </AntiIcing>
    </DRCSUB>
    """.utf8)

    @Test("DRCSUB: receipt routing and fluid volumes with units")
    func parsesDRCSUB() throws {
        let m = try DeIcingParser().parse(data: Self.drcsub)
        #expect(m.messageSubtype == "DRCSUB")
        #expect(m.deIcingProviderID == "XYZ")
        #expect(m.deIcingReceiptNumber == "RCPT-0042")
        let t = try #require(m.treatment)
        #expect(t.isAntiIcing == true)
        #expect(t.deIcingFluidVolume?.value == 120)
        #expect(t.deIcingFluidVolume?.unit == "l")
        #expect(t.antiIcingFluidType == 4)
        #expect(t.antiIcingFluidVolume?.value == 40)
    }

    // MARK: - DRCACK (De-Icing Receipt Acknowledge, bare anti-icing code)

    private static let drcack = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <DRCACK xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-12-01T06:35:00Z"/>
      <M633SupplementaryHeader/>
      <AntiIcingCode>
        <AntiIcingFluidType>3</AntiIcingFluidType>
        <AntiIcingFluidMix>75</AntiIcingFluidMix>
        <ActualAntiIcingBeginTime>2030-12-01T06:25:00Z</ActualAntiIcingBeginTime>
      </AntiIcingCode>
    </DRCACK>
    """.utf8)

    @Test("DRCACK: bare anti-icing code treatment")
    func parsesDRCACK() throws {
        let m = try DeIcingParser().parse(data: Self.drcack)
        #expect(m.messageSubtype == "DRCACK")
        let t = try #require(m.treatment)
        #expect(t.isAntiIcing == true)
        #expect(t.antiIcingFluidType == 3)
        #expect(t.antiIcingFluidMix == 75)
        #expect(t.actualAntiIcingBeginTime == "2030-12-01T06:25:00Z")
        #expect(t.deIcingFluidType == nil)
    }
}
