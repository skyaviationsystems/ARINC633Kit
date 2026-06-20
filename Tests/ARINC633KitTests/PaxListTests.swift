// PaxListTests.swift
// ARINC633KitTests
//
// Synthetic PaxList fixtures — fictional carrier, fabricated passenger names/IDs,
// no real PII or operational data.
//
// The registry still routes PaxList to a generic StubMessage, so these tests call
// PaxListParser().parse(data:) directly and assert on the returned PaxList.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("PaxList")
struct PaxListTests {

    private static let xml = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <PaxList xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-05-07T07:54:00Z"/>
      <M633SupplementaryHeader>
        <Flight flightOriginDate="2030-05-07" scheduledTimeOfDeparture="2030-05-07T11:50:00Z">
          <FlightIdentification>
            <FlightNumber airlineIATACode="ZZ" number="100">
              <CommercialFlightNumber>ZZ100</CommercialFlightNumber>
            </FlightNumber>
          </FlightIdentification>
          <DepartureAirport airportName="Testfield Alpha">
            <AirportIATACode>TFA</AirportIATACode>
          </DepartureAirport>
          <ArrivalAirport airportName="Testfield Bravo">
            <AirportIATACode>TFB</AirportIATACode>
          </ArrivalAirport>
        </Flight>
        <Aircraft aircraftRegistration="ZZ-TST">
          <AircraftModel airlineSpecificSubType="388">
            <AircraftICAOType>A388</AircraftICAOType>
          </AircraftModel>
        </Aircraft>
      </M633SupplementaryHeader>
      <PaxListDetails>
        <PaxInfo>
          <PersonInfo>
            <PersonalInfo givenName="Ada" surname="Tester" title="Dr.">
              <Gender>female</Gender>
              <Nationality>Testlandic</Nationality>
              <DateOfBirth>1980-01-01</DateOfBirth>
            </PersonalInfo>
            <Languages>
              <Language>Testlandic</Language>
              <Language>English</Language>
            </Languages>
            <TravelDocument placeOfBirth="Testville" dateOfIssue="2025-01-01"
              travelDocumentId="TDOC000001" dateOfBirth="1980-01-01"
              countryOfIssue="Testland" dateOfExpiration="2035-01-01"
              nationality="Testlandic" placeOfIssue="Testville" travelDocumentType="Passport"/>
          </PersonInfo>
          <PaxFlightInfo class="Business" seat="01A" cabinSection="FWD">
            <ImportantPassenger>
              <Level Level="HON"/>
              <FrequentTravellerNumber>ZZ/000000000001</FrequentTravellerNumber>
              <CustomerEquity>12345</CustomerEquity>
              <RewardsAccountInfo>67890</RewardsAccountInfo>
            </ImportantPassenger>
            <TravellerGroup>G1</TravellerGroup>
            <ServiceRequests>
              <ServiceRequest request="AsianVegetarianMeal" requestType="AVML"/>
            </ServiceRequests>
            <SpecialAssistances>
              <SpecialAssistance request="wheelchair" requestType="WCHR"/>
            </SpecialAssistances>
            <ConnectionInfo>
              <IncomingFlights>
                <IncomingFlight flightOriginDate="2030-05-07">
                  <FlightIdentification>
                    <FlightNumber airlineIATACode="ZZ" number="050">
                      <CommercialFlightNumber>ZZ050</CommercialFlightNumber>
                    </FlightNumber>
                  </FlightIdentification>
                  <DepartureAirport><AirportIATACode>TFC</AirportIATACode></DepartureAirport>
                  <ArrivalAirport><AirportIATACode>TFA</AirportIATACode></ArrivalAirport>
                </IncomingFlight>
              </IncomingFlights>
            </ConnectionInfo>
          </PaxFlightInfo>
          <PersonToContact givenName="Ben" surname="Tester">
            <Gender>male</Gender>
            <ContactInfo>
              <Address street="1 Test Way" postalCode="00001" city="Testville" country="Testland"/>
            </ContactInfo>
          </PersonToContact>
        </PaxInfo>
        <PaxInfo>
          <PersonInfo>
            <PersonalInfo givenName="Cleo" surname="Sample">
              <Gender>female</Gender>
            </PersonalInfo>
          </PersonInfo>
          <Company companyName="Acme Test Corp">
            <CorporateRecognition>CR0001</CorporateRecognition>
          </Company>
          <PaxFlightInfo class="Economy" seat="30C">
            <TravellerGroup>G2</TravellerGroup>
          </PaxFlightInfo>
        </PaxInfo>
      </PaxListDetails>
    </PaxList>
    """.utf8)

    @Test("Parses header, supplementary header, and passenger count")
    func parsesEnvelopeAndCount() throws {
        let pax = try PaxListParser().parse(data: Self.xml)
        #expect(pax.header.versionNumber == "4")
        #expect(pax.header.timestamp == "2030-05-07T07:54:00Z")
        #expect(pax.supplementaryHeader.flight.departure.iataCode == "TFA")
        #expect(pax.supplementaryHeader.flight.arrival.iataCode == "TFB")
        #expect(pax.passengers.count == 2)
    }

    @Test("Maps person identity, travel document, languages")
    func parsesPerson() throws {
        let pax = try PaxListParser().parse(data: Self.xml)
        let p = try #require(pax.passengers.first)
        #expect(p.person.givenName == "Ada")
        #expect(p.person.surname == "Tester")
        #expect(p.person.title == "Dr.")
        #expect(p.person.gender == "female")
        #expect(p.person.nationality == "Testlandic")
        #expect(p.person.dateOfBirth == "1980-01-01")
        #expect(p.person.languages == ["Testlandic", "English"])
        #expect(p.person.travelDocument?.documentId == "TDOC000001")
        #expect(p.person.travelDocument?.documentType == "Passport")
        #expect(p.person.travelDocument?.countryOfIssue == "Testland")
        #expect(p.person.travelDocument?.dateOfExpiration == "2035-01-01")
    }

    @Test("Maps flight info: seat, class, importance, requests, connection")
    func parsesFlightInfo() throws {
        let pax = try PaxListParser().parse(data: Self.xml)
        let f = try #require(pax.passengers.first?.flightInfo)
        #expect(f.seat == "01A")
        #expect(f.travelClass == "Business")
        #expect(f.cabinSection == "FWD")
        #expect(f.travellerGroup == "G1")
        #expect(f.importantPassenger?.level == "HON")
        #expect(f.importantPassenger?.frequentTravellerNumber == "ZZ/000000000001")
        #expect(f.importantPassenger?.customerEquity == 12345)
        #expect(f.importantPassenger?.rewardsAccountInfo == 67890)
        #expect(f.serviceRequests.first?.request == "AsianVegetarianMeal")
        #expect(f.serviceRequests.first?.requestType == "AVML")
        #expect(f.specialAssistances.first?.requestType == "WCHR")

        let inbound = try #require(f.connection?.incomingFlights.first)
        #expect(inbound.commercialFlightNumber == "ZZ050")
        #expect(inbound.airlineCode == "ZZ")
        #expect(inbound.flightNumber == "050")
        #expect(inbound.departureAirport == "TFC")
        #expect(inbound.arrivalAirport == "TFA")
    }

    @Test("Maps person-to-contact address and company")
    func parsesContactAndCompany() throws {
        let pax = try PaxListParser().parse(data: Self.xml)
        let contact = try #require(pax.passengers.first?.personToContact)
        #expect(contact.givenName == "Ben")
        #expect(contact.surname == "Tester")
        #expect(contact.address?.city == "Testville")
        #expect(contact.address?.country == "Testland")
        #expect(contact.address?.postalCode == "00001")

        let second = try #require(pax.passengers.last)
        #expect(second.company?.companyName == "Acme Test Corp")
        #expect(second.company?.corporateRecognition == "CR0001")
        #expect(second.flightInfo.travelClass == "Economy")
        #expect(second.flightInfo.travellerGroup == "G2")
    }
}
