// AirspaceDataTests.swift
// ARINC633KitTests
//
// Synthetic AirspaceData fixtures — fictional airspace volumes, no real operational data.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("AirspaceData")
struct AirspaceDataTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <AirspaceData flightPlanId="OFP-TEST-1" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight>
          <DepartureAirport><AirportICAOCode>ZZZA</AirportICAOCode></DepartureAirport>
        </Flight>
      </M633SupplementaryHeader>
      <Airspace airspaceICAOCode="ZZQX" airspaceName="TESTLAND_FIR" airspaceType="FIR" sequence="1">
        <Entry cumulatedFlightTime="PT0S">
          <Coordinates latitude="180000.0" longitude="36000.0"/>
          <CumulatedGroundDistance unit="m">0.0</CumulatedGroundDistance>
          <NearestWaypoint waypointId="ZZZA" waypointName="ZZZA" countryICAOCode="ZZ">
            <Coordinates latitude="180000.0" longitude="36000.0"/>
            <Function>Airport</Function>
          </NearestWaypoint>
        </Entry>
        <Exit cumulatedFlightTime="PT10M40S">
          <Coordinates latitude="-90000.0" longitude="-72000.0"/>
          <CumulatedGroundDistance unit="m">108000.0</CumulatedGroundDistance>
        </Exit>
        <GreatCircleDistance unit="NM">579.25</GreatCircleDistance>
        <GroundDistance unit="NM">600.0</GroundDistance>
        <EnrouteChargesInformation distanceMethod="GCD" localCurrency="EUR" amountInLocalCurrency="123.45" unifiedCurrency="USD" amountInUnifiedCurrency="135.0"/>
        <OverflightPermitInformation permitId="ZZ-PERMIT01" isPermitRequired="true"/>
        <ZZVendorTag custom="1"/>
      </Airspace>
      <Airspace airspaceName="TESTLAND_OCEANIC" airspaceType="UIR"/>
    </AirspaceData>
    """.utf8)

    @Test("Parses airspaces, border points, coordinates, charges, permit")
    func parsesAirspaces() throws {
        guard case let .airspaceData(msg) = try ARINC633Parser().parse(data: Self.xml) else {
            Issue.record("Expected .airspaceData"); return
        }
        #expect(msg.flightPlanId == "OFP-TEST-1")
        #expect(msg.header.versionNumber == "4")
        #expect(msg.airspaces.count == 2)

        let a = try #require(msg.airspaces.first)
        #expect(a.airspaceICAOCode == "ZZQX")
        #expect(a.airspaceName == "TESTLAND_FIR")
        #expect(a.airspaceType == "FIR")
        #expect(a.sequence == "1")

        // Entry border point + coordinate conversion (arc-seconds -> degrees).
        let entry = try #require(a.entry)
        #expect(entry.cumulatedFlightTime == "PT0S")
        #expect(entry.coordinates?.latitude == 50.0)   // 180000 / 3600
        #expect(entry.coordinates?.longitude == 10.0)  // 36000 / 3600
        #expect(entry.cumulatedGroundDistance?.value == 0.0)
        #expect(entry.cumulatedGroundDistance?.unit == "m")
        #expect(entry.nearestWaypoint?.waypointId == "ZZZA")
        #expect(entry.nearestWaypoint?.function == "Airport")
        #expect(entry.nearestWaypoint?.coordinates?.latitude == 50.0)

        // Exit border point with negative (South/West) coordinates.
        let exit = try #require(a.exit)
        #expect(exit.coordinates?.latitude == -25.0)   // -90000 / 3600
        #expect(exit.coordinates?.longitude == -20.0)  // -72000 / 3600

        // Distances across the volume.
        #expect(a.greatCircleDistance?.value == 579.25)
        #expect(a.greatCircleDistance?.unit == "NM")
        #expect(a.groundDistance?.value == 600.0)

        // Charges and permit.
        #expect(a.enrouteCharges?.distanceMethod == "GCD")
        #expect(a.enrouteCharges?.localCurrency == "EUR")
        #expect(a.enrouteCharges?.amountInLocalCurrency == 123.45)
        #expect(a.enrouteCharges?.unifiedCurrency == "USD")
        #expect(a.enrouteCharges?.amountInUnifiedCurrency == 135.0)
        #expect(a.overflightPermit?.permitId == "ZZ-PERMIT01")
        #expect(a.overflightPermit?.isPermitRequired == true)

        // Unrecognized child swept into the airspace extensions bag.
        #expect(a.extensions.contains { $0.name == "ZZVendorTag" })

        // Second airspace: name-only volume with no entry/exit.
        let b = msg.airspaces[1]
        #expect(b.airspaceName == "TESTLAND_OCEANIC")
        #expect(b.airspaceType == "UIR")
        #expect(b.entry == nil)
        #expect(b.exit == nil)
    }
}
