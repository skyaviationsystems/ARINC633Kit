// PaxList.swift
// ARINC633Kit
//
// Typed model for the PaxList (passenger list) message.
// Source: PaxList.xsd (root <PaxList>), sample PaxList_1.xml.
//
// Structure: <PaxList> -> <PaxListDetails> (PaxListType) -> one <PaxInfo> per
// passenger (PaxInfoType), each with a <PersonInfo> (PersonType: identity, travel
// document, languages), an optional <Company>, a required <PaxFlightInfo>
// (PaxFlightInfoType: seat/class/cabin, frequent-traveller importance, service &
// special-assistance requests, connection itinerary) and an optional
// <PersonToContact>. An optional <PaxListText> carries a human-readable rendering.

import Foundation

// MARK: - Top Level

/// A parsed PaxList message: the passenger manifest for a flight.
///
/// XSD: root `<PaxList>` in PaxList.xsd. Sequence is `<M633Header>`,
/// optional `<M633SupplementaryHeader>`, optional `<PaxListDetails>`,
/// optional `<PaxListText>`, then an `##other` extension slot.
public struct PaxList: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`, required).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0)
    /// carrying flight/aircraft context for the manifest.
    public let supplementaryHeader: SupplementaryHeader

    /// One entry per passenger (`<PaxListDetails>/<PaxInfo>`, PaxListType).
    /// Empty when `<PaxListDetails>` is absent (it is optional in the schema).
    public var passengers: [PaxInfo]

    /// Human-readable passenger-list text (`<PaxListText>`, TextType, minOccurs=0),
    /// with `<Text>` paragraphs joined by newlines.
    public var paxListText: String?

    /// Unrecognized top-level child elements preserved verbatim
    /// (the schema's `##other` extension slot and any vendor additions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                passengers: [PaxInfo] = [],
                paxListText: String? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.passengers = passengers
        self.paxListText = paxListText
        self.extensions = extensions
    }
}

// MARK: - Passenger

/// A single passenger entry (`<PaxInfo>`, PaxInfoType).
///
/// XSD sequence: `<PersonInfo>` (required), `<Company>` (optional),
/// `<PaxFlightInfo>` (required), `<PersonToContact>` (optional), `##other`.
public struct PaxInfo: Sendable, Equatable {
    /// Passenger identity, travel document and languages
    /// (`<PersonInfo>`, PersonType — required).
    public var person: PaxPerson

    /// Employing/sponsoring company, if the passenger travels on corporate
    /// business (`<Company>`, CompanyType — optional).
    public var company: PaxCompany?

    /// Per-flight booking details: seat, class, importance, requests, itinerary
    /// (`<PaxFlightInfo>`, PaxFlightInfoType — required).
    public var flightInfo: PaxFlightInfo

    /// Emergency / next-of-kin contact person
    /// (`<PersonToContact>`, PersonalInfoType — optional).
    public var personToContact: PaxContactPerson?

    public init(person: PaxPerson = PaxPerson(),
                company: PaxCompany? = nil,
                flightInfo: PaxFlightInfo = PaxFlightInfo(),
                personToContact: PaxContactPerson? = nil) {
        self.person = person
        self.company = company
        self.flightInfo = flightInfo
        self.personToContact = personToContact
    }
}

// MARK: - Person

/// Passenger identity block (`<PersonInfo>`, PersonType from m633common.xsd).
public struct PaxPerson: Sendable, Equatable {
    /// Surname (`PersonalInfo/@surname`, required in the schema).
    public var surname: String?
    /// Given name(s) — anything other than surname (`PersonalInfo/@givenName`).
    public var givenName: String?
    /// Preferred name (`PersonalInfo/@preferredName`, optional).
    public var preferredName: String?
    /// Academic or nobility title, e.g. "Dr." (`PersonalInfo/@title`, optional).
    public var title: String?
    /// Gender (`PersonalInfo/<Gender>`, GenderType, e.g. "male"/"female").
    public var gender: String?
    /// Nationality (`PersonalInfo/<Nationality>`, optional).
    public var nationality: String?
    /// Date of birth, ISO `xs:date` (`PersonalInfo/<DateOfBirth>`, optional).
    public var dateOfBirth: String?

    /// Languages spoken (`<Languages>/<Language>`, optional, repeatable).
    public var languages: [String]

    /// Travel document (passport/ID), if present
    /// (`<TravelDocument>`, TravelDocumentType, minOccurs=0).
    public var travelDocument: PaxTravelDocument?

    public init(surname: String? = nil,
                givenName: String? = nil,
                preferredName: String? = nil,
                title: String? = nil,
                gender: String? = nil,
                nationality: String? = nil,
                dateOfBirth: String? = nil,
                languages: [String] = [],
                travelDocument: PaxTravelDocument? = nil) {
        self.surname = surname
        self.givenName = givenName
        self.preferredName = preferredName
        self.title = title
        self.gender = gender
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.languages = languages
        self.travelDocument = travelDocument
    }
}

/// A contact / next-of-kin person (`<PersonToContact>`, PersonalInfoType).
///
/// PersonalInfoType is the same identity shape as a passenger's `<PersonalInfo>`
/// but stands alone here (no travel document / languages), and may carry an
/// optional postal `<Address>` via `<ContactInfo>`.
public struct PaxContactPerson: Sendable, Equatable {
    /// Surname (`@surname`, required).
    public var surname: String?
    /// Given name (`@givenName`).
    public var givenName: String?
    /// Preferred name (`@preferredName`, optional).
    public var preferredName: String?
    /// Title (`@title`, optional).
    public var title: String?
    /// Gender (`<Gender>`, optional).
    public var gender: String?
    /// Nationality (`<Nationality>`, optional).
    public var nationality: String?
    /// Date of birth, ISO `xs:date` (`<DateOfBirth>`, optional).
    public var dateOfBirth: String?
    /// Postal address (`<ContactInfo>/<Address>`, optional).
    public var address: PaxAddress?

    public init(surname: String? = nil,
                givenName: String? = nil,
                preferredName: String? = nil,
                title: String? = nil,
                gender: String? = nil,
                nationality: String? = nil,
                dateOfBirth: String? = nil,
                address: PaxAddress? = nil) {
        self.surname = surname
        self.givenName = givenName
        self.preferredName = preferredName
        self.title = title
        self.gender = gender
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.address = address
    }
}

/// A postal address (`<ContactInfo>/<Address>`, ContactInfoType from m633common.xsd).
public struct PaxAddress: Sendable, Equatable {
    /// Street / PO box (`@street`, required).
    public var street: String?
    /// City (`@city`, required).
    public var city: String?
    /// ZIP / postal code (`@postalCode`, required).
    public var postalCode: String?
    /// Country (`@country`).
    public var country: String?

    public init(street: String? = nil, city: String? = nil,
                postalCode: String? = nil, country: String? = nil) {
        self.street = street
        self.city = city
        self.postalCode = postalCode
        self.country = country
    }
}

/// Passenger travel document (`<TravelDocument>`, TravelDocumentType).
///
/// All fields are XML attributes on the `<TravelDocument>` element.
public struct PaxTravelDocument: Sendable, Equatable {
    /// Document type, e.g. "Passport", "ID card" (`@travelDocumentType`).
    public var documentType: String?
    /// Document number/identifier (`@travelDocumentId`, required).
    public var documentId: String?
    /// Date of birth, ISO `xs:date` (`@dateOfBirth`, required).
    public var dateOfBirth: String?
    /// Place of birth (`@placeOfBirth`, required).
    public var placeOfBirth: String?
    /// Nationality (`@nationality`).
    public var nationality: String?
    /// Place of issue (`@placeOfIssue`).
    public var placeOfIssue: String?
    /// Date of issue, ISO `xs:date` (`@dateOfIssue`, required).
    public var dateOfIssue: String?
    /// Country of issue (`@countryOfIssue`).
    public var countryOfIssue: String?
    /// Date of expiration, ISO `xs:date` (`@dateOfExpiration`).
    public var dateOfExpiration: String?

    public init(documentType: String? = nil, documentId: String? = nil,
                dateOfBirth: String? = nil, placeOfBirth: String? = nil,
                nationality: String? = nil, placeOfIssue: String? = nil,
                dateOfIssue: String? = nil, countryOfIssue: String? = nil,
                dateOfExpiration: String? = nil) {
        self.documentType = documentType
        self.documentId = documentId
        self.dateOfBirth = dateOfBirth
        self.placeOfBirth = placeOfBirth
        self.nationality = nationality
        self.placeOfIssue = placeOfIssue
        self.dateOfIssue = dateOfIssue
        self.countryOfIssue = countryOfIssue
        self.dateOfExpiration = dateOfExpiration
    }
}

// MARK: - Company

/// Corporate sponsor of a passenger (`<Company>`, CompanyType).
public struct PaxCompany: Sendable, Equatable {
    /// Company name (`@companyName`, required).
    public var companyName: String?
    /// Corporate recognition / programme code (`<CorporateRecognition>`, optional).
    public var corporateRecognition: String?

    public init(companyName: String? = nil, corporateRecognition: String? = nil) {
        self.companyName = companyName
        self.corporateRecognition = corporateRecognition
    }
}

// MARK: - Flight Info

/// Per-flight booking and service details for a passenger
/// (`<PaxFlightInfo>`, PaxFlightInfoType).
public struct PaxFlightInfo: Sendable, Equatable {
    /// Seat assignment, e.g. "15K" (`@seat`, optional).
    public var seat: String?
    /// Cabin/booking class (`@class`, optional; XSD default "Economy",
    /// enumerated First/Business/PremiumEconomy/Economy/Other).
    public var travelClass: String?
    /// Cabin section identifier (`@cabinSection`, optional).
    public var cabinSection: String?

    /// Frequent-traveller / importance information
    /// (`<ImportantPassenger>`, ImportanceType, minOccurs=0).
    public var importantPassenger: PaxImportance?

    /// Passenger identification level (`<IDPax>`, LevelType — its `Level`
    /// attribute, minOccurs=0).
    public var idPaxLevel: String?

    /// Traveller group code, e.g. for parties booked together
    /// (`<TravellerGroup>`, minOccurs=0).
    public var travellerGroup: String?

    /// Free-text comments (`<Comments>/<Comment>`, TextType, repeatable).
    public var comments: [String]

    /// Special service requests not relevant to an emergency, e.g. special meals
    /// (`<ServiceRequests>/<ServiceRequest>`, PaxRequestType, repeatable).
    public var serviceRequests: [PaxRequest]

    /// Special assistance requests possibly relevant to an emergency, e.g.
    /// wheelchair (`<SpecialAssistances>/<SpecialAssistance>`, PaxRequestType).
    public var specialAssistances: [PaxRequest]

    /// Inbound/outbound connecting flights
    /// (`<ConnectionInfo>`, ConnectionInfoType, minOccurs=0).
    public var connection: PaxConnectionInfo?

    public init(seat: String? = nil,
                travelClass: String? = nil,
                cabinSection: String? = nil,
                importantPassenger: PaxImportance? = nil,
                idPaxLevel: String? = nil,
                travellerGroup: String? = nil,
                comments: [String] = [],
                serviceRequests: [PaxRequest] = [],
                specialAssistances: [PaxRequest] = [],
                connection: PaxConnectionInfo? = nil) {
        self.seat = seat
        self.travelClass = travelClass
        self.cabinSection = cabinSection
        self.importantPassenger = importantPassenger
        self.idPaxLevel = idPaxLevel
        self.travellerGroup = travellerGroup
        self.comments = comments
        self.serviceRequests = serviceRequests
        self.specialAssistances = specialAssistances
        self.connection = connection
    }
}

/// Frequent-traveller / VIP importance block (`<ImportantPassenger>`, ImportanceType).
public struct PaxImportance: Sendable, Equatable {
    /// Importance level code, e.g. "HON", "SEN", "FTL", "MAM"
    /// (`<Level>` element's `Level` attribute, LevelType, required).
    public var level: String?
    /// Frequent-traveller number (`<FrequentTravellerNumber>`, optional).
    public var frequentTravellerNumber: String?
    /// Customer equity value (`<CustomerEquity>`, xs:long, optional).
    public var customerEquity: Int?
    /// Rewards / mileage account balance (`<RewardsAccountInfo>`, xs:long, optional).
    public var rewardsAccountInfo: Int?

    public init(level: String? = nil,
                frequentTravellerNumber: String? = nil,
                customerEquity: Int? = nil,
                rewardsAccountInfo: Int? = nil) {
        self.level = level
        self.frequentTravellerNumber = frequentTravellerNumber
        self.customerEquity = customerEquity
        self.rewardsAccountInfo = rewardsAccountInfo
    }
}

/// A special service or special-assistance request (`PaxRequestType`).
public struct PaxRequest: Sendable, Equatable {
    /// The request description, e.g. "AsianVegetarianMeal", "wheelchair"
    /// (`@request`, required).
    public var request: String?
    /// Airline-assigned request code, e.g. "AVML", "WCHR" (`@requestType`, optional).
    public var requestType: String?

    public init(request: String? = nil, requestType: String? = nil) {
        self.request = request
        self.requestType = requestType
    }
}

// MARK: - Connection Info

/// Connecting-flight itinerary for a passenger
/// (`<ConnectionInfo>`, ConnectionInfoType).
public struct PaxConnectionInfo: Sendable, Equatable {
    /// Inbound connecting flights (`<IncomingFlights>/<IncomingFlight>`, FlightType).
    public var incomingFlights: [PaxConnectionFlight]
    /// Onward connecting flights (`<OutgoingFlights>/<OutgoingFlight>`, FlightType).
    public var outgoingFlights: [PaxConnectionFlight]

    public init(incomingFlights: [PaxConnectionFlight] = [],
                outgoingFlights: [PaxConnectionFlight] = []) {
        self.incomingFlights = incomingFlights
        self.outgoingFlights = outgoingFlights
    }
}

/// A single connecting flight (`<IncomingFlight>` / `<OutgoingFlight>`, FlightType).
public struct PaxConnectionFlight: Sendable, Equatable {
    /// Flight origin date, ISO `xs:date` (`@flightOriginDate`).
    public var flightOriginDate: String?
    /// Operating airline IATA code (`FlightNumber/@airlineIATACode`).
    public var airlineCode: String?
    /// Flight number (`FlightNumber/@number`).
    public var flightNumber: String?
    /// Commercial flight number, e.g. "LH710" (`<CommercialFlightNumber>`).
    public var commercialFlightNumber: String?
    /// Departure airport IATA code (`DepartureAirport/<AirportIATACode>`).
    public var departureAirport: String?
    /// Arrival airport IATA code (`ArrivalAirport/<AirportIATACode>`).
    public var arrivalAirport: String?

    public init(flightOriginDate: String? = nil,
                airlineCode: String? = nil,
                flightNumber: String? = nil,
                commercialFlightNumber: String? = nil,
                departureAirport: String? = nil,
                arrivalAirport: String? = nil) {
        self.flightOriginDate = flightOriginDate
        self.airlineCode = airlineCode
        self.flightNumber = flightNumber
        self.commercialFlightNumber = commercialFlightNumber
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
    }
}
