// CapturedElement+Header.swift
// ARINC633Kit
//
// Extracts the ARINC 633 message envelope from a captured tree, so typed parsers can
// be written as straightforward tree-walks over `GenericElementParser` output:
//   1. capture the whole document  ->  CapturedElement
//   2. envelope = root.makeARINC633Header() / root.makeSupplementaryHeader()
//   3. map known payload children to typed fields; sweep the rest into an
//      `extensions: [CapturedElement]` bag (nothing dropped).

import Foundation

public extension CapturedElement {

    /// Extract `<M633Header>` / `<M633LTDHeader>` from anywhere in the subtree.
    ///
    /// Per m633headers.xsd both `versionNumber` and `timestamp` are attributes;
    /// `messageSequence` is optional and absent in official samples.
    func makeARINC633Header() -> ARINC633Header {
        guard let h = firstDescendant(named: "M633Header") ?? firstDescendant(named: "M633LTDHeader") else {
            return ARINC633Header()
        }
        return ARINC633Header(
            versionNumber: h.attribute("versionNumber") ?? "",
            timestamp: h.attribute("timestamp") ?? "",
            messageSequence: h.attribute("messageSequence")
        )
    }

    /// Extract `<M633SupplementaryHeader>` / `<M633LTDSupplementaryHeader>`.
    ///
    /// Captures `FlightKeyIdentifier` (optional UUID), flight identification,
    /// departure/arrival ICAO/IATA + `airportName`, aircraft registration/type, and
    /// `airlineSpecificSubType`. Returns an empty header when none is present.
    func makeSupplementaryHeader() -> SupplementaryHeader {
        guard let s = firstDescendant(named: "M633SupplementaryHeader")
                ?? firstDescendant(named: "M633LTDSupplementaryHeader") else {
            return SupplementaryHeader()
        }

        let flightEl = s.firstDescendant(named: "Flight")
        let numberEl = s.firstDescendant(named: "FlightNumber")
        let dep = s.firstDescendant(named: "DepartureAirport")
        let arr = s.firstDescendant(named: "ArrivalAirport")
        let aircraft = s.firstDescendant(named: "Aircraft")
        let model = s.firstDescendant(named: "AircraftModel")

        let flight = ARINCHeaderFlight(
            airlineCode: numberEl?.attribute("airlineIATACode") ?? numberEl?.attribute("airlineICAOCode") ?? "",
            flightNumber: numberEl?.attribute("number") ?? "",
            flightIdentifier: s.firstDescendant(named: "FlightIdentifier")?.text.trimmedOrNil,
            commercialFlightNumber: s.firstDescendant(named: "CommercialFlightNumber")?.text.trimmedOrNil,
            departure: airport(from: dep),
            arrival: airport(from: arr),
            scheduledDepartureTime: flightEl?.attribute("scheduledTimeOfDeparture"),
            flightOriginDate: flightEl?.attribute("flightOriginDate")
        )
        let ac = ARINCHeaderAircraft(
            registration: aircraft?.attribute("aircraftRegistration") ?? "",
            aircraftType: (model?.firstDescendant(named: "AircraftICAOType")
                           ?? model?.firstDescendant(named: "AircraftIATAType"))?.text.trimmedOrNil,
            engineType: model?.attribute("airlineSpecificSubType")
        )
        return SupplementaryHeader(
            flight: flight,
            aircraft: ac,
            flightKeyIdentifier: s.firstDescendant(named: "FlightKeyIdentifier")?.text.trimmedOrNil
        )
    }

    /// Names of envelope elements that typed parsers should NOT treat as payload.
    static let envelopeChildNames: Set<String> = [
        "M633Header", "M633LTDHeader",
        "M633SupplementaryHeader", "M633LTDSupplementaryHeader"
    ]

    private func airport(from el: CapturedElement?) -> ARINCHeaderAirport {
        guard let el else { return ARINCHeaderAirport() }
        return ARINCHeaderAirport(
            icaoCode: el.firstDescendant(named: "AirportICAOCode")?.text ?? "",
            iataCode: el.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil,
            name: el.attribute("airportName")
        )
    }
}
