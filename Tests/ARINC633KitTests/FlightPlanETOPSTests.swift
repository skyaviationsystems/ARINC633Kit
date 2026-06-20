// FlightPlanETOPSTests.swift
// ARINC633KitTests
//
// Synthetic FlightPlan ETOPS fixture locking the borderTime audit fix.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("FlightPlan ETOPS")
struct FlightPlanETOPSTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FlightPlan xmlns="http://aeec.aviation-ia.net/633" flightPlanId="1">
      <M633Header versionNumber="5" timestamp="2030-01-01T00:00:00Z"/>
      <ETOPSSummary ruleTime="PT3H00M00S" borderTime="PT3H46M00S"/>
    </FlightPlan>
    """.utf8)

    @Test("ETOPSSummary borderTime and ruleTime are both captured")
    func borderTimeCaptured() throws {
        guard case let .flightPlan(plan) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .flightPlan"); return
        }
        let etops = try #require(plan.etopsSummary)
        #expect(etops.isETOPS == true)
        #expect(etops.ruleTime != nil)
        #expect(etops.borderTime != nil)        // previously dropped (audit fix)
    }
}
