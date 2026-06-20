// CrewList.swift
// ARINC633Kit
//
// Models for ARINC 633-4 CrewList message type.
// Based on CrewList.xsd schema.

import Foundation

// MARK: - Top Level

/// Parsed CrewList message containing flight crew information.
public struct CrewList: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public var header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public var supplementaryHeader: SupplementaryHeader

    /// Crew members.
    public var members: [CrewMember]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                members: [CrewMember] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.members = members
    }
}

// MARK: - Crew Member

/// A single crew member with personal and duty information.
public struct CrewMember: Sendable, Equatable {
    /// Whether this is a cockpit crew member (true) or cabin crew (false).
    public var isCockpitCrew: Bool

    /// Surname.
    public var surname: String?
    /// Given name.
    public var givenName: String?
    /// Title (Dr., Mr., etc.).
    public var title: String?
    /// Gender.
    public var gender: String?

    /// Crew rank code (CP, SF, CA, P1, P2, CAT, etc.).
    public var rank: CrewRank
    /// Duty code (PIC, FO, CC, U1L, P2, etc.).
    public var dutyCode: DutyCode
    /// Raw duty code string (preserving original value).
    public var dutyCodeRaw: String?
    /// Employee ID.
    public var employeeId: String?
    /// Department.
    public var department: String?
    /// License number.
    public var licenseNumber: String?
    /// Seniority number.
    public var seniority: Int?

    /// Languages spoken.
    public var languages: [String]

    /// Qualifications.
    public var qualifications: [String]

    /// Travel document information.
    public var travelDocument: CrewTravelDocument?

    /// Non-smoking room request.
    public var nonSmokingRoomRequest: Bool?

    public init(isCockpitCrew: Bool = false, surname: String? = nil,
                givenName: String? = nil, title: String? = nil,
                gender: String? = nil, rank: CrewRank = .unknown(""),
                dutyCode: DutyCode = .unknown(""), dutyCodeRaw: String? = nil,
                employeeId: String? = nil, department: String? = nil,
                licenseNumber: String? = nil, seniority: Int? = nil,
                languages: [String] = [], qualifications: [String] = [],
                travelDocument: CrewTravelDocument? = nil,
                nonSmokingRoomRequest: Bool? = nil) {
        self.isCockpitCrew = isCockpitCrew
        self.surname = surname
        self.givenName = givenName
        self.title = title
        self.gender = gender
        self.rank = rank
        self.dutyCode = dutyCode
        self.dutyCodeRaw = dutyCodeRaw
        self.employeeId = employeeId
        self.department = department
        self.licenseNumber = licenseNumber
        self.seniority = seniority
        self.languages = languages
        self.qualifications = qualifications
        self.travelDocument = travelDocument
        self.nonSmokingRoomRequest = nonSmokingRoomRequest
    }
}

// MARK: - Travel Document

/// Crew member travel document (passport, etc.).
public struct CrewTravelDocument: Sendable, Equatable {
    public var documentType: String?
    public var documentId: String?
    public var nationality: String?
    public var dateOfBirth: String?
    public var placeOfBirth: String?
    public var dateOfIssue: String?
    public var dateOfExpiration: String?
    public var countryOfIssue: String?
    public var placeOfIssue: String?

    public init(documentType: String? = nil, documentId: String? = nil,
                nationality: String? = nil, dateOfBirth: String? = nil,
                placeOfBirth: String? = nil, dateOfIssue: String? = nil,
                dateOfExpiration: String? = nil, countryOfIssue: String? = nil,
                placeOfIssue: String? = nil) {
        self.documentType = documentType
        self.documentId = documentId
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.placeOfBirth = placeOfBirth
        self.dateOfIssue = dateOfIssue
        self.dateOfExpiration = dateOfExpiration
        self.countryOfIssue = countryOfIssue
        self.placeOfIssue = placeOfIssue
    }
}
