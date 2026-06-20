// GeneralErrorTests.swift
// ARINC633KitTests
//
// Synthetic GERIND fixtures — fictional services/codes, no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("GeneralError")
struct GeneralErrorTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <GERIND xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight flightOriginDate="2030-05-07" scheduledTimeOfDeparture="2030-05-07T11:10:00">
          <FlightIdentification>
            <FlightNumber airlineIATACode="ZZ" number="999">
              <CommercialFlightNumber>ZZ999</CommercialFlightNumber>
            </FlightNumber>
          </FlightIdentification>
        </Flight>
      </M633SupplementaryHeader>
      <Error erroneousSMI="ZZX" erroneousService="ZZS" erroneousElement="ZZE" erroneousVersion="3" errorClass="2" errorType="9" errorData="DEAD" tryAgain="0"/>
      <ZZVendorTag custom="1"/>
    </GERIND>
    """.utf8)

    @Test("Parses error report attributes and sweeps extensions")
    func parsesError() throws {
        let msg = try GeneralErrorParser().parse(data: Self.xml)

        #expect(msg.header.versionNumber == "4")
        let e = msg.error
        #expect(e.erroneousSMI == "ZZX")
        #expect(e.erroneousService == "ZZS")
        #expect(e.erroneousElement == "ZZE")
        #expect(e.erroneousVersion == 3)
        #expect(e.errorClass == 2)
        #expect(e.errorType == 9)
        #expect(e.errorData == "DEAD")
        #expect(e.tryAgain == false)

        // The vendor tag is unmodeled payload and must be preserved.
        #expect(msg.extensions.contains { $0.name == "ZZVendorTag" })
        #expect(!msg.extensions.contains { $0.name == "Error" })
    }

    @Test("Defaults are empty when no Error element is present")
    func handlesMissingError() throws {
        let xml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <GERIND xmlns="http://aeec.aviation-ia.net/633">
          <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
        </GERIND>
        """.utf8)

        let msg = try GeneralErrorParser().parse(data: xml)
        #expect(msg.error.erroneousService == nil)
        #expect(msg.error.tryAgain == nil)
        #expect(msg.extensions.isEmpty)
    }
}
