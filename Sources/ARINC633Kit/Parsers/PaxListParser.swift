// PaxListParser.swift
// ARINC633Kit
//
// Parser for the PaxList message (root <PaxList>, PaxList.xsd).
//
// Tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, then <PaxListDetails>/<PaxInfo> entries are mapped to
// typed `PaxInfo` models, with any unrecognized top-level children swept into the
// model's `extensions` bag (nothing dropped).

import Foundation

/// Parses a `<PaxList>` document into a `PaxList`.
public final class PaxListParser: Sendable {

    public init() {}

    /// Parse PaxList XML into a typed `PaxList`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> PaxList {
        let root = try GenericElementParser().parse(data: data)

        var message = PaxList(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        if let details = root.firstDescendant(named: "PaxListDetails") {
            message.passengers = details.all(named: "PaxInfo").map(Self.passenger)
        }

        if let textEl = root.firstDescendant(named: "PaxListText") {
            let texts = Self.collectText(textEl)
            message.paxListText = texts.isEmpty ? textEl.text.trimmedOrNil
                                                : texts.joined(separator: "\n")
        }

        // Preserve any unmodeled top-level payload children (##other extension slot).
        message.extensions = root.payloadChildren.filter {
            $0.name != "PaxListDetails" && $0.name != "PaxListText"
        }
        return message
    }

    // MARK: - PaxInfo

    private static func passenger(from el: CapturedElement) -> PaxInfo {
        var pax = PaxInfo()
        if let personEl = el.first(named: "PersonInfo") {
            pax.person = person(from: personEl)
        }
        if let companyEl = el.first(named: "Company") {
            pax.company = company(from: companyEl)
        }
        if let flightEl = el.first(named: "PaxFlightInfo") {
            pax.flightInfo = flightInfo(from: flightEl)
        }
        if let contactEl = el.first(named: "PersonToContact") {
            pax.personToContact = contactPerson(from: contactEl)
        }
        return pax
    }

    // MARK: - Person

    private static func person(from el: CapturedElement) -> PaxPerson {
        var p = PaxPerson()
        let info = el.first(named: "PersonalInfo")
        p.surname = info?.attribute("surname")
        p.givenName = info?.attribute("givenName")
        p.preferredName = info?.attribute("preferredName")
        p.title = info?.attribute("title")
        p.gender = info?.first(named: "Gender")?.text.trimmedOrNil
        p.nationality = info?.first(named: "Nationality")?.text.trimmedOrNil
        p.dateOfBirth = info?.first(named: "DateOfBirth")?.text.trimmedOrNil

        if let langs = el.first(named: "Languages") {
            p.languages = langs.all(named: "Language").compactMap { $0.text.trimmedOrNil }
        }
        if let doc = el.first(named: "TravelDocument") {
            p.travelDocument = travelDocument(from: doc)
        }
        return p
    }

    private static func contactPerson(from el: CapturedElement) -> PaxContactPerson {
        var c = PaxContactPerson()
        c.surname = el.attribute("surname")
        c.givenName = el.attribute("givenName")
        c.preferredName = el.attribute("preferredName")
        c.title = el.attribute("title")
        c.gender = el.first(named: "Gender")?.text.trimmedOrNil
        c.nationality = el.first(named: "Nationality")?.text.trimmedOrNil
        c.dateOfBirth = el.first(named: "DateOfBirth")?.text.trimmedOrNil
        if let addr = el.firstDescendant(named: "Address") {
            c.address = PaxAddress(
                street: addr.attribute("street"),
                city: addr.attribute("city"),
                postalCode: addr.attribute("postalCode"),
                country: addr.attribute("country")
            )
        }
        return c
    }

    private static func travelDocument(from el: CapturedElement) -> PaxTravelDocument {
        PaxTravelDocument(
            documentType: el.attribute("travelDocumentType"),
            documentId: el.attribute("travelDocumentId"),
            dateOfBirth: el.attribute("dateOfBirth"),
            placeOfBirth: el.attribute("placeOfBirth"),
            nationality: el.attribute("nationality"),
            placeOfIssue: el.attribute("placeOfIssue"),
            dateOfIssue: el.attribute("dateOfIssue"),
            countryOfIssue: el.attribute("countryOfIssue"),
            dateOfExpiration: el.attribute("dateOfExpiration")
        )
    }

    // MARK: - Company

    private static func company(from el: CapturedElement) -> PaxCompany {
        PaxCompany(
            companyName: el.attribute("companyName"),
            corporateRecognition: el.first(named: "CorporateRecognition")?.text.trimmedOrNil
        )
    }

    // MARK: - Flight Info

    private static func flightInfo(from el: CapturedElement) -> PaxFlightInfo {
        var f = PaxFlightInfo()
        f.seat = el.attribute("seat")
        f.travelClass = el.attribute("class")
        f.cabinSection = el.attribute("cabinSection")

        if let imp = el.first(named: "ImportantPassenger") {
            f.importantPassenger = importance(from: imp)
        }
        // <IDPax> carries its value in a `Level` attribute (LevelType).
        f.idPaxLevel = el.first(named: "IDPax")?.attribute("Level")
        f.travellerGroup = el.first(named: "TravellerGroup")?.text.trimmedOrNil

        if let comments = el.first(named: "Comments") {
            f.comments = comments.all(named: "Comment").compactMap {
                let texts = collectText($0)
                return texts.isEmpty ? $0.text.trimmedOrNil : texts.joined(separator: "\n")
            }
        }
        if let reqs = el.first(named: "ServiceRequests") {
            f.serviceRequests = reqs.all(named: "ServiceRequest").map(request)
        }
        if let assists = el.first(named: "SpecialAssistances") {
            f.specialAssistances = assists.all(named: "SpecialAssistance").map(request)
        }
        if let conn = el.first(named: "ConnectionInfo") {
            f.connection = connectionInfo(from: conn)
        }
        return f
    }

    private static func importance(from el: CapturedElement) -> PaxImportance {
        PaxImportance(
            level: el.first(named: "Level")?.attribute("Level"),
            frequentTravellerNumber: el.first(named: "FrequentTravellerNumber")?.text.trimmedOrNil,
            customerEquity: el.first(named: "CustomerEquity")?.intValue,
            rewardsAccountInfo: el.first(named: "RewardsAccountInfo")?.intValue
        )
    }

    private static func request(from el: CapturedElement) -> PaxRequest {
        PaxRequest(request: el.attribute("request"), requestType: el.attribute("requestType"))
    }

    // MARK: - Connection

    private static func connectionInfo(from el: CapturedElement) -> PaxConnectionInfo {
        var c = PaxConnectionInfo()
        if let incoming = el.first(named: "IncomingFlights") {
            c.incomingFlights = incoming.all(named: "IncomingFlight").map(connectionFlight)
        }
        if let outgoing = el.first(named: "OutgoingFlights") {
            c.outgoingFlights = outgoing.all(named: "OutgoingFlight").map(connectionFlight)
        }
        return c
    }

    private static func connectionFlight(from el: CapturedElement) -> PaxConnectionFlight {
        let number = el.firstDescendant(named: "FlightNumber")
        let dep = el.first(named: "DepartureAirport")
        let arr = el.first(named: "ArrivalAirport")
        return PaxConnectionFlight(
            flightOriginDate: el.attribute("flightOriginDate"),
            airlineCode: number?.attribute("airlineIATACode") ?? number?.attribute("airlineICAOCode"),
            flightNumber: number?.attribute("number"),
            commercialFlightNumber: el.firstDescendant(named: "CommercialFlightNumber")?.text.trimmedOrNil,
            departureAirport: dep?.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil,
            arrivalAirport: arr?.firstDescendant(named: "AirportIATACode")?.text.trimmedOrNil
        )
    }

    // MARK: - Text

    /// Collect text from all `<Text>` descendants (handles `<Paragraph><Text>`).
    private static func collectText(_ el: CapturedElement) -> [String] {
        var out: [String] = []
        func walk(_ node: CapturedElement) {
            if node.name == "Text", let t = node.text.trimmedOrNil { out.append(t) }
            node.children.forEach(walk)
        }
        walk(el)
        return out
    }
}
