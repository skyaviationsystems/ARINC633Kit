// FoundationTests.swift
// ARINC633KitTests
//
// Tests for the dispatch registry, capture fallback, custom-handler extensibility,
// header extraction, and error handling. All fixtures are SYNTHETIC — fictional
// carrier, fake registration/UUIDs, no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit
import ARINC633KitSUPP

// MARK: - Synthetic fixtures

private enum Fixtures {
    /// Minimal synthetic ATIS (header-only path) with a FlightKeyIdentifier UUID.
    static let atis = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <ATIS xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-01-01T00:00:00Z"/>
      <M633SupplementaryHeader>
        <FlightKeyIdentifier>00000000-0000-0000-0000-000000000abc</FlightKeyIdentifier>
        <Flight flightOriginDate="2030-01-01" scheduledTimeOfDeparture="2030-01-01T01:00:00Z">
          <FlightIdentification>
            <FlightIdentifier>ZZ9999</FlightIdentifier>
            <FlightNumber airlineIATACode="ZZ" number="9999">
              <CommercialFlightNumber>ZZ9999</CommercialFlightNumber>
            </FlightNumber>
          </FlightIdentification>
          <DepartureAirport airportName="TEST ALPHA">
            <AirportICAOCode>ZZZA</AirportICAOCode>
            <AirportIATACode>TSA</AirportIATACode>
          </DepartureAirport>
          <ArrivalAirport airportName="TEST BRAVO">
            <AirportICAOCode>ZZZB</AirportICAOCode>
            <AirportIATACode>TSB</AirportIATACode>
          </ArrivalAirport>
        </Flight>
        <Aircraft aircraftRegistration="N0TEST">
          <AircraftModel airlineSpecificSubType="B777F-TEST">
            <AircraftICAOType>B77F</AircraftICAOType>
          </AircraftModel>
        </Aircraft>
      </M633SupplementaryHeader>
    </ATIS>
    """.utf8)

    /// Synthetic LTD using the LTD header variants.
    static let ltd = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <LoadAndTrimData xmlns="http://aeec.aviation-ia.net/633" LoadAndTrimSheetId="01">
      <M633LTDHeader versionNumber="4" timestamp="2030-02-02T02:02:02Z"/>
      <M633LTDSupplementaryHeader>
        <Flight>
          <FlightIdentification>
            <FlightNumber airlineIATACode="ZZ" number="1"/>
          </FlightIdentification>
          <DepartureAirport><AirportIATACode>TSA</AirportIATACode></DepartureAirport>
          <ArrivalAirport><AirportIATACode>TSB</AirportIATACode></ArrivalAirport>
        </Flight>
        <Aircraft aircraftRegistration="N0LTD">
          <AircraftModel airlineSpecificSubType="A321-TEST"/>
        </Aircraft>
      </M633LTDSupplementaryHeader>
    </LoadAndTrimData>
    """.utf8)

    /// A wholly unknown root element — should be captured, never dropped.
    static let unknownRoot = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <ZZSomeUnknownRoot foo="bar">
      <Child id="1">hello</Child>
      <Child id="2">world</Child>
      <Wrapper><Deep>nested</Deep></Wrapper>
    </ZZSomeUnknownRoot>
    """.utf8)

    /// Synthetic Lido SUPP AdditionalRemarks (vendor extension).
    static let supp = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <AdditionalRemarks>
      <AdditionalRemarkDetails>
        <Remark RemarkType="GEN" Title="RELEASE REMARKS">SYNTHETIC RELEASE TEXT</Remark>
        <Remark RemarkType="GEN" Title="CREW QUALIFICATIONS">CA 100001     DOE J
    LAST TO:   2030-01-01        LAST LNDG:   2030-01-02</Remark>
      </AdditionalRemarkDetails>
    </AdditionalRemarks>
    """.utf8)
}

// MARK: - Registry & dispatch

@Suite("Registry dispatch")
struct RegistryTests {

    @Test("Known root dispatches to its typed handler")
    func knownRoot() throws {
        let message = try ARINC633Parser().parse(data: Fixtures.atis)
        guard case let .atis(atis) = message else {
            Issue.record("Expected .atis, got \(message)")
            return
        }
        #expect(atis.header.versionNumber == "4")
    }

    @Test("Unknown root yields .captured (nothing dropped)")
    func unknownRootCaptured() throws {
        let message = try ARINC633Parser().parse(data: Fixtures.unknownRoot)
        guard case let .captured(root) = message else {
            Issue.record("Expected .captured, got \(message)")
            return
        }
        #expect(root.name == "ZZSomeUnknownRoot")
        #expect(root.attribute("foo") == "bar")
        #expect(root.all(named: "Child").count == 2)
    }

    @Test("Custom registration does not disturb built-ins")
    func customDoesNotDisturbBuiltins() throws {
        let registry = ARINC633MessageRegistry.standard
            .registering("ZZSomeUnknownRoot") { _ in .custom(DummyCustom()) }
        let parser = ARINC633Parser(registry: registry)

        // Built-in still works.
        if case .atis = try parser.parse(data: Fixtures.atis) {} else {
            Issue.record("Built-in ATIS dispatch broke after custom registration")
        }
        // Custom now handles the formerly-unknown root.
        guard case let .custom(custom) = try parser.parse(data: Fixtures.unknownRoot) else {
            Issue.record("Expected .custom")
            return
        }
        #expect(custom.rootElement == "ZZDUMMY")
    }

    @Test("versionNumber values 2/3/4/5 are all accepted")
    func versionNumbersAccepted() throws {
        for v in ["2", "3", "4", "5"] {
            let xml = Data("""
            <ATIS xmlns="http://aeec.aviation-ia.net/633">
              <M633Header versionNumber="\(v)" timestamp="2030-01-01T00:00:00Z"/>
            </ATIS>
            """.utf8)
            guard case let .atis(atis) = try ARINC633Parser().parse(data: xml) else {
                Issue.record("Expected .atis for version \(v)")
                return
            }
            #expect(atis.header.versionNumber == v)
        }
    }
}

private struct DummyCustom: ARINC633CustomMessage {
    var rootElement: String { "ZZDUMMY" }
}

// MARK: - Header extraction

@Suite("Header extraction")
struct HeaderTests {

    @Test("Standard header with FlightKeyIdentifier, names, subtype")
    func standardHeader() throws {
        guard case let .atis(atis) = try ARINC633Parser().parse(data: Fixtures.atis) else {
            Issue.record("Expected .atis"); return
        }
        let supp = atis.supplementaryHeader
        #expect(supp.flightKeyIdentifier == "00000000-0000-0000-0000-000000000abc")
        #expect(supp.flight.departure.icaoCode == "ZZZA")
        #expect(supp.flight.departure.name == "TEST ALPHA")
        #expect(supp.flight.arrival.name == "TEST BRAVO")
        #expect(supp.aircraft.registration == "N0TEST")
        #expect(supp.aircraft.engineType == "B777F-TEST")
    }

    @Test("FlightKeyIdentifier absent parses to nil")
    func flightKeyAbsent() throws {
        let xml = Data("""
        <ATIS xmlns="http://aeec.aviation-ia.net/633">
          <M633Header versionNumber="4" timestamp="2030-01-01T00:00:00Z"/>
          <M633SupplementaryHeader>
            <Aircraft aircraftRegistration="N0X"/>
          </M633SupplementaryHeader>
        </ATIS>
        """.utf8)
        guard case let .atis(atis) = try ARINC633Parser().parse(data: xml) else {
            Issue.record("Expected .atis"); return
        }
        #expect(atis.supplementaryHeader.flightKeyIdentifier == nil)
    }

    @Test("LTD header variants are recognized")
    func ltdHeaderVariants() throws {
        let message = try ARINC633Parser().parse(data: Fixtures.ltd)
        guard case let .loadAndTrimData(ltd) = message else {
            Issue.record("Expected .loadAndTrimData, got \(message)"); return
        }
        #expect(ltd.header.versionNumber == "4")
        #expect(ltd.header.timestamp == "2030-02-02T02:02:02Z")
    }
}

// MARK: - Custom handler / SUPP module

@Suite("SUPP custom extension")
struct SUPPTests {

    @Test("AdditionalRemarks surfaces as .custom via registeringSUPP()")
    func suppAsCustom() throws {
        let parser = ARINC633Parser.withSUPP()
        let message = try parser.parse(data: Fixtures.supp)
        guard case let .custom(custom) = message else {
            Issue.record("Expected .custom, got \(message)"); return
        }
        let remarks = try #require(custom as? AdditionalRemarks)
        #expect(remarks.rootElement == "AdditionalRemarks")
        #expect(remarks.releaseRemarks == "SYNTHETIC RELEASE TEXT")
        #expect(remarks.crewQualifications.first?.name == "DOE J")
    }

    @Test("Without SUPP, AdditionalRemarks is captured, not custom")
    func withoutSUPPCaptured() throws {
        let message = try ARINC633Parser().parse(data: Fixtures.supp)
        guard case let .captured(root) = message else {
            Issue.record("Expected .captured, got \(message)"); return
        }
        #expect(root.name == "AdditionalRemarks")
        #expect(root.firstDescendant(named: "Remark") != nil)
    }
}

// MARK: - CapturedElement queries

@Suite("CapturedElement queries")
struct CapturedElementTests {

    @Test("first / all / firstDescendant / attribute")
    func queries() throws {
        guard case let .captured(root) = try ARINC633Parser().parse(data: Fixtures.unknownRoot) else {
            Issue.record("Expected .captured"); return
        }
        #expect(root.first(named: "Child")?.attribute("id") == "1")
        #expect(root.all(named: "Child").map { $0.text } == ["hello", "world"])
        #expect(root.firstDescendant(named: "Deep")?.text == "nested")
        #expect(root.first(named: "Nope") == nil)
        #expect(root.firstDescendant(named: "Wrapper")?.first(named: "Deep")?.text == "nested")
    }
}

// MARK: - Error / edge inputs

@Suite("Error handling")
struct ErrorTests {

    @Test("Empty data throws")
    func emptyData() {
        #expect(throws: ARINC633ParseError.self) {
            _ = try ARINC633Parser().parse(data: Data())
        }
    }

    @Test("Non-XML bytes throw")
    func nonXML() {
        #expect(throws: ARINC633ParseError.self) {
            _ = try ARINC633Parser().parse(data: Data("not xml at all {]}".utf8))
        }
    }

    @Test("Truncated XML throws")
    func truncated() {
        let xml = Data("<ATIS xmlns=\"http://aeec.aviation-ia.net/633\"><M633Header ".utf8)
        #expect(throws: (any Error).self) {
            _ = try ARINC633Parser().parse(data: xml)
        }
    }
}
