// WBATests.swift
// ARINC633KitTests
//
// Synthetic WBA fixtures — fictional flights/aircraft, no real operational data.
// All values are invented for testing the tree-walk parser.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("WBA")
struct WBATests {

    // A WIFSUB (Init-Submit, Full mode) carrying the broad shared payload.
    private static let wifsub = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <WIFSUB xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight flightOriginDate="2030-05-07" scheduledTimeOfDeparture="2030-05-07T10:20:00">
          <FlightIdentification>
            <FlightIdentifier>ZZZ9999</FlightIdentifier>
            <FlightNumber airlineIATACode="ZZ" number="9999"/>
          </FlightIdentification>
          <DepartureAirport><AirportICAOCode>ZZZA</AirportICAOCode></DepartureAirport>
          <ArrivalAirport><AirportICAOCode>ZZZB</AirportICAOCode></ArrivalAirport>
        </Flight>
        <Aircraft aircraftRegistration="ZZTST"/>
      </M633SupplementaryHeader>
      <Units volumeUnit="l" weightUnit="kg" armLeverUnit="MT"/>
      <Configuration>
        <ConfigurationCode>STD</ConfigurationCode>
        <EntryMode>REDUCED</EntryMode>
        <CrewCode>2/4</CrewCode>
        <Catering>
          <CateringDeviationPerGalleyZone zone="G" weight="150"/>
        </Catering>
        <Miscellaneous>
          <MiscellaneousCode>Ballast</MiscellaneousCode>
          <MiscellaneousItem designation="Other" weight="1500" hArm="43.5"/>
        </Miscellaneous>
      </Configuration>
      <DryOperating>
        <DOW>100000</DOW>
        <DOCG>326</DOCG>
      </DryOperating>
      <Loading>
        <ZFW>120000</ZFW>
        <ZFCG>342</ZFCG>
        <FOB>80000</FOB>
        <TaxiFuel>700</TaxiFuel>
        <TripFuel>73000</TripFuel>
        <FuelDensity>0.785</FuelDensity>
      </Loading>
      <Payload>
        <PaxPerClass>
          <Class classId="C" classSeats="20"/>
          <Class classId="Y" classSeats="180"/>
        </PaxPerClass>
        <TotalPaxNumber>200</TotalPaxNumber>
        <PaxDistribution>
          <PaxPerSection section="OA" sectionPaxNumber="100"/>
          <PaxPerSection section="OB" sectionPaxNumber="100"/>
        </PaxDistribution>
        <TotalPaxWeight>20000</TotalPaxWeight>
        <CargoDistribution>
          <CargoPerCompartment compartment="CP1" compartmentCargoWeight="4000"/>
          <CargoPerCompartment compartment="CP2" compartmentCargoWeight="3000"/>
        </CargoDistribution>
        <TotalCargoWeight>7000</TotalCargoWeight>
        <TotalTrafficWeight>27000</TotalTrafficWeight>
      </Payload>
      <TO_Check>
        <TOW>200000</TOW>
        <TOCG>395</TOCG>
      </TO_Check>
      <CrewNumber>
        <CockpitCrew>2</CockpitCrew>
        <CabinCrewMale>2</CabinCrewMale>
        <CabinCrewFemale>2</CabinCrewFemale>
      </CrewNumber>
      <EditionNumber>1</EditionNumber>
      <CheckedBy>TESTER</CheckedBy>
      <BalanceSeating>CABIN SECTION TRIMMING</BalanceSeating>
      <AdditionalInfo>Synthetic test note</AdditionalInfo>
      <ZZVendorTag custom="1"/>
    </WIFSUB>
    """.utf8)

    // A WIRREP (downlink Error Report) — different subtype, report content only.
    private static let wirrep = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <WIRREP xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T08:00:00Z"/>
      <M633SupplementaryHeader>
        <Aircraft aircraftRegistration="ZZTST"/>
      </M633SupplementaryHeader>
      <WI_Error>
        <Error category="WARNING" label="ConfCd not defined">detail text</Error>
        <Error category="ERROR" label="ZFW out of range"/>
      </WI_Error>
      <WI_Message>WIMSUB reference body</WI_Message>
    </WIRREP>
    """.utf8)

    @Test("WIFSUB: subtype, units, weights, CG, distributions, config, extensions")
    func parsesWifsub() throws {
        let msg = try WBAParser().parse(data: Self.wifsub)

        #expect(msg.messageSubtype == "WIFSUB")
        #expect(msg.header.versionNumber == "4")

        // Units context.
        #expect(msg.units?.weightUnit == "kg")
        #expect(msg.units?.armLeverUnit == "MT")

        // Dry operating: weight tagged with the shared unit; CG in 0.1% MAC.
        #expect(msg.dryOperating?.weight?.value == 100000)
        #expect(msg.dryOperating?.weight?.unit == "kg")
        #expect(msg.dryOperating?.centreOfGravity == 326)

        // Loading.
        #expect(msg.loading?.zeroFuel?.weight?.value == 120000)
        #expect(msg.loading?.zeroFuel?.centreOfGravity == 342)
        #expect(msg.loading?.fuelOnBoard?.value == 80000)
        #expect(msg.loading?.tripFuel?.value == 73000)
        #expect(msg.loading?.fuelDensity == 0.785)

        // Payload totals.
        #expect(msg.payload?.totalPaxWeight?.value == 20000)
        #expect(msg.payload?.totalCargoWeight?.value == 7000)
        #expect(msg.payload?.totalTrafficWeight?.value == 27000)
        #expect(msg.payload?.totalTrafficWeight?.unit == "kg")

        // Take-off cross-check.
        #expect(msg.takeoffCheck?.weight?.value == 200000)
        #expect(msg.takeoffCheck?.centreOfGravity == 395)

        // Crew / pax / cargo distribution.
        #expect(msg.crewNumber?.cockpitCrew == 2)
        #expect(msg.crewNumber?.cabinCrewFemale == 2)
        #expect(msg.totalPaxNumber == 200)
        #expect(msg.paxPerClass.map(\.classId) == ["C", "Y"])
        #expect(msg.paxPerClass.first?.seats == 20)
        #expect(msg.paxDistribution.map(\.section) == ["OA", "OB"])
        #expect(msg.paxDistribution.first?.paxNumber == 100)
        #expect(msg.cargoDistribution.map(\.compartment) == ["CP1", "CP2"])
        #expect(msg.cargoDistribution.first?.weight == 4000)

        // Configuration block.
        #expect(msg.configuration?.entryMode == "REDUCED")
        #expect(msg.configuration?.crewCode == "2/4")
        #expect(msg.configuration?.cateringDeviations.first?.zone == "G")
        #expect(msg.configuration?.cateringDeviations.first?.weight == 150)
        #expect(msg.configuration?.miscellaneousCodes == ["Ballast"])
        #expect(msg.configuration?.miscellaneousItems.first?.designation == "Other")
        #expect(msg.configuration?.miscellaneousItems.first?.horizontalArm == 43.5)
        #expect(msg.configurationCode == "STD")

        // Report-ish fields.
        #expect(msg.editionNumber == 1)
        #expect(msg.checkedBy == "TESTER")
        #expect(msg.balanceSeating == "CABIN SECTION TRIMMING")
        #expect(msg.additionalInfo == "Synthetic test note")

        // Unmapped vendor child preserved.
        #expect(msg.extensions.contains { $0.name == "ZZVendorTag" })
    }

    @Test("WIRREP: subtype, errors, reported message; no W&B figures")
    func parsesWirrep() throws {
        let msg = try WBAParser().parse(data: Self.wirrep)

        #expect(msg.messageSubtype == "WIRREP")
        #expect(msg.errors.count == 2)
        #expect(msg.errors.first?.category == "WARNING")
        #expect(msg.errors.first?.label == "ConfCd not defined")
        #expect(msg.errors.first?.text == "detail text")
        #expect(msg.errors.last?.category == "ERROR")
        #expect(msg.reportedMessage == "WIMSUB reference body")

        // Error reports carry no weight/balance payload.
        #expect(msg.units == nil)
        #expect(msg.dryOperating == nil)
        #expect(msg.loading == nil)
        #expect(msg.payload == nil)
    }
}
