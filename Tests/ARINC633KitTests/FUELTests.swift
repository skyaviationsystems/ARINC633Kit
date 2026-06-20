// FUELTests.swift
// ARINC633KitTests
//
// Synthetic FUEL-family fixtures — fictional airports, flights, and fuel figures.
// No real operational or copyrighted schema/sample data is reproduced here.
//
// These tests call FUELParser().parse(data:) directly (the central registry is not yet
// rewired to FUELParser).

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("FUEL")
struct FUELTests {

    // MARK: - FORSUB (Fuel Order Submit)

    private static let forsubXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FORSUB xmlns="http://aeec.aviation-ia.net/633"
            acknowledgementRequired="true" finalFuelIndicator="true"
            aircraftMassUnitDisplay="kg" refuelingRequiredIndicator="true">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight flightOriginDate="2030-05-07" scheduledTimeOfDeparture="2030-05-07T10:20:00">
          <FlightIdentification>
            <FlightIdentifier>ZZZ9001</FlightIdentifier>
            <FlightNumber airlineIATACode="ZZ" number="9001"/>
          </FlightIdentification>
          <DepartureAirport><AirportICAOCode>ZZZA</AirportICAOCode></DepartureAirport>
          <ArrivalAirport><AirportICAOCode>ZZZB</AirportICAOCode></ArrivalAirport>
        </Flight>
        <Aircraft aircraftRegistration="ZTEST"/>
      </M633SupplementaryHeader>
      <ServiceAirport>ZZZA</ServiceAirport>
      <IntoPlaneServiceCode>ZZP</IntoPlaneServiceCode>
      <ServiceFlight airlineIATACode="ZZ" number="9001"/>
      <OperationalLimit unit="kg" reason="TakeOffPerformance">150000</OperationalLimit>
      <BlockFuel unit="kg">159000</BlockFuel>
      <TaxiFuel unit="kg">1000</TaxiFuel>
      <TripFuel unit="kg">144900</TripFuel>
      <ArrivalFuel actual="false" unit="kg">1200</ArrivalFuel>
      <FuelTruckOnStandby>false</FuelTruckOnStandby>
      <ZZVendorTag custom="1"/>
    </FORSUB>
    """.utf8)

    @Test("FORSUB: subtype, order attributes, fuel masses with units, extensions")
    func parsesForsub() throws {
        let msg = try FUELParser().parse(data: Self.forsubXML)
        #expect(msg.messageSubtype == "FORSUB")
        #expect(msg.header.versionNumber == "4")
        #expect(msg.supplementaryHeader.flight.departure.icaoCode == "ZZZA")

        let order = try #require(msg.order)
        #expect(order.refuelingRequired == true)
        #expect(order.acknowledgementRequired == true)
        #expect(order.finalFuelIndicator == true)
        #expect(order.aircraftMassUnitDisplay == "kg")
        #expect(order.serviceAirport == "ZZZA")
        #expect(order.intoPlaneServiceCode == "ZZP")
        #expect(order.serviceFlight?.name == "ServiceFlight")

        #expect(order.operationalLimit?.value == 150000)
        #expect(order.operationalLimit?.unit == "kg")
        #expect(order.operationalLimitReason == "TakeOffPerformance")
        #expect(order.blockFuel?.value == 159000)
        #expect(order.blockFuel?.unit == "kg")
        #expect(order.taxiFuel?.value == 1000)
        #expect(order.tripFuel?.value == 144900)
        #expect(order.arrivalFuel?.value == 1200)
        #expect(order.arrivalFuelActual == false)
        #expect(order.fuelTruckOnStandby == false)

        // Unmapped vendor child preserved, mapped children excluded.
        #expect(msg.extensions.contains { $0.name == "ZZVendorTag" })
        #expect(!msg.extensions.contains { $0.name == "BlockFuel" })

        // No other subtype payloads populated.
        #expect(msg.status == nil)
        #expect(msg.receipt == nil)
        #expect(msg.error == nil)
    }

    // MARK: - FSTREP (Fuel Status Report)

    private static let fstrepXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FSTREP xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <status>
        <CurrentZFW>320500</CurrentZFW>
        <CurrentZFWSource>F</CurrentZFWSource>
        <ZFWEntryDate>2030-05-07T00:55:00-00:00</ZFWEntryDate>
        <CurrentZFCG>385</CurrentZFCG>
        <CurrentZFCGSource>A</CurrentZFCGSource>
        <ZFCGEntryDate>2030-05-06T23:59:00-00:00</ZFCGEntryDate>
        <CurrentPFQ>230000</CurrentPFQ>
        <CurrentPFQSource>N</CurrentPFQSource>
        <PFQEntryDate>2030-05-06T23:29:00-00:00</PFQEntryDate>
        <GWCG>397</GWCG>
        <GWCGAccuracyState>N</GWCGAccuracyState>
        <FOB>230100</FOB>
        <FOBAccuracyState>N</FOBAccuracyState>
        <TTK>4200</TTK>
        <TTKAccuracyState>N</TTKAccuracyState>
        <AircraftMassUnitDisplayed>KG</AircraftMassUnitDisplayed>
      </status>
    </FSTREP>
    """.utf8)

    @Test("FSTREP: subtype, full fuel status block, unit context")
    func parsesFstrep() throws {
        let msg = try FUELParser().parse(data: Self.fstrepXML)
        #expect(msg.messageSubtype == "FSTREP")

        let s = try #require(msg.status)
        #expect(s.currentZFW == 320500)
        #expect(s.currentZFWSource == "F")
        #expect(s.zfwEntryDate == "2030-05-07T00:55:00-00:00")
        #expect(s.currentZFCG == 385)
        #expect(s.currentPFQ == 230000)
        #expect(s.gwcg == 397)
        #expect(s.fob == 230100)
        #expect(s.fobAccuracyState == "N")
        #expect(s.ttk == 4200)
        #expect(s.aircraftMassUnitDisplayed == "KG")

        #expect(msg.order == nil)
        #expect(msg.extensions.isEmpty)
    }

    // MARK: - FRCSUB (Fuel Receipt Submit)

    private static let frcsubXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FRCSUB xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Aircraft aircraftRegistration="ZTEST"/>
      </M633SupplementaryHeader>
      <IntoPlaneServiceCode>ZZP</IntoPlaneServiceCode>
      <FuelTruckId>TRUCK01</FuelTruckId>
      <FuelTruckId>TRUCK02</FuelTruckId>
      <RefuelingDefuelingIndicator>false</RefuelingDefuelingIndicator>
      <FuelReceiptNumber>9001-1</FuelReceiptNumber>
      <FuelVolume unit="l">134250</FuelVolume>
      <FuelDensity unit="kg/l">800</FuelDensity>
      <FuelType>JETA1</FuelType>
    </FRCSUB>
    """.utf8)

    @Test("FRCSUB: receipt, volume/density units, truck ids")
    func parsesFrcsub() throws {
        let msg = try FUELParser().parse(data: Self.frcsubXML)
        #expect(msg.messageSubtype == "FRCSUB")

        let r = try #require(msg.receipt)
        #expect(r.intoPlaneServiceCode == "ZZP")
        #expect(r.fuelTruckIds == ["TRUCK01", "TRUCK02"])
        #expect(r.defuelingIndicator == false)
        #expect(r.fuelReceiptNumber == "9001-1")
        #expect(r.fuelVolume?.value == 134250)
        #expect(r.fuelVolume?.unit == "l")
        #expect(r.fuelMass == nil)
        #expect(r.fuelDensity?.value == 800)
        #expect(r.fuelDensity?.unit == "kg/l")
        #expect(r.fuelType == "JETA1")
        #expect(msg.extensions.isEmpty)
    }

    // MARK: - FCAIND (Fuel CG Advisory Indication)

    private static let fcaindXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FCAIND xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Aircraft aircraftRegistration="ZTEST"/>
      </M633SupplementaryHeader>
      <FwdTakeoffCenterOfGravityLimit>36.5</FwdTakeoffCenterOfGravityLimit>
      <AftTakeoffCenterOfGravityLimit>42.5</AftTakeoffCenterOfGravityLimit>
      <CalculatedTakeoffCenterOfGravity>35.1</CalculatedTakeoffCenterOfGravity>
      <TakeoffWeight unit="kg">500300</TakeoffWeight>
      <TaxiFuel unit="kg">1125</TaxiFuel>
    </FCAIND>
    """.utf8)

    @Test("FCAIND: CG advisory percentages and weights")
    func parsesFcaind() throws {
        let msg = try FUELParser().parse(data: Self.fcaindXML)
        #expect(msg.messageSubtype == "FCAIND")

        let cg = try #require(msg.cgAdvisory)
        #expect(cg.fwdTakeoffCGLimit == 36.5)
        #expect(cg.aftTakeoffCGLimit == 42.5)
        #expect(cg.calculatedTakeoffCG == 35.1)
        #expect(cg.takeoffWeight?.value == 500300)
        #expect(cg.takeoffWeight?.unit == "kg")
        #expect(cg.taxiFuel?.value == 1125)
        #expect(msg.extensions.isEmpty)
    }

    // MARK: - FERIND (Fuel Error Indication)

    private static let ferindXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FERIND xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <Error erroneousService="FDA" erroneousElement="SUB" erroneousVersion="1"
             errorClass="1" errorType="1" errorData="Z3A2"/>
    </FERIND>
    """.utf8)

    @Test("FERIND: error descriptor attributes")
    func parsesFerind() throws {
        let msg = try FUELParser().parse(data: Self.ferindXML)
        #expect(msg.messageSubtype == "FERIND")

        let e = try #require(msg.error)
        #expect(e.erroneousService == "FDA")
        #expect(e.erroneousElement == "SUB")
        #expect(e.erroneousVersion == 1)
        #expect(e.errorClass == 1)
        #expect(e.errorType == 1)
        #expect(e.errorData == "Z3A2")
    }

    // MARK: - FDASUB (Fuel Data Submit) — DATA block

    private static let fdasubXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FDASUB xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <DATA>
        <CurrentPFQ>230000</CurrentPFQ>
        <FinalRefuelOperation>0</FinalRefuelOperation>
      </DATA>
    </FDASUB>
    """.utf8)

    @Test("FDASUB: fuel data block with boolean coercion")
    func parsesFdasub() throws {
        let msg = try FUELParser().parse(data: Self.fdasubXML)
        #expect(msg.messageSubtype == "FDASUB")

        let d = try #require(msg.data)
        #expect(d.currentPFQ == 230000)
        #expect(d.currentZFW == nil)
        #expect(d.finalRefuelOperation == false)
    }

    // MARK: - FSTREQ (Fuel Status Request) — header-only

    private static let fstreqXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <FSTREQ xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
    </FSTREQ>
    """.utf8)

    @Test("FSTREQ: header-only request carries subtype and no payload")
    func parsesFstreq() throws {
        let msg = try FUELParser().parse(data: Self.fstreqXML)
        #expect(msg.messageSubtype == "FSTREQ")
        #expect(msg.header.versionNumber == "4")
        #expect(msg.status == nil)
        #expect(msg.order == nil)
        #expect(msg.extensions.isEmpty)
    }
}
