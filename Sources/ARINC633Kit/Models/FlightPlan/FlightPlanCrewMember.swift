// FlightPlanCrewMember.swift
// ARINC633Kit
//
// Crew member data from the <CrewList> inside <FlightInfo> in 633-5 FlightPlan XML.
// These are simpler than the standalone CrewList message type -- all data comes from
// self-closing <CrewMember> element attributes.

import Foundation

/// A crew member from the FlightPlan's embedded `<CrewList>` element.
///
/// This is the simplified crew representation found inside `<FlightInfo>` in ARINC 633-5
/// FlightPlan XML, where all data is carried as attributes on a self-closing `<CrewMember>`
/// element. For the full standalone CrewList message type with travel documents, languages,
/// and qualifications, see ``CrewMember``.
///
/// Name is stored in raw "Last, First" format. Use ``firstName``, ``lastName``, and
/// ``displayName`` computed properties for parsed name components.
public struct FlightPlanCrewMember: Sendable, Equatable {

    /// Raw name string from the XML (e.g., "Moore, John" or "Irby Jr., Almous (Al)").
    public var name: String

    /// Duty code string (e.g., "Captain", "FirstOfficer").
    public var dutyCode: String

    /// Pilot license number, if provided.
    public var licenseNumber: String?

    /// Employee ID, if provided.
    public var employeeId: String?

    /// Whether this crew member is part of the cockpit crew.
    public var isCockpitCrew: Bool

    public init(name: String = "",
                dutyCode: String = "",
                licenseNumber: String? = nil,
                employeeId: String? = nil,
                isCockpitCrew: Bool = false) {
        self.name = name
        self.dutyCode = dutyCode
        self.licenseNumber = licenseNumber
        self.employeeId = employeeId
        self.isCockpitCrew = isCockpitCrew
    }

    // MARK: - Computed Name Properties

    /// Last name parsed from the raw name string.
    ///
    /// For "Moore, John" returns "Moore".
    /// For "Irby Jr., Almous (Al)" returns "Irby Jr.".
    /// Falls back to the full name if no comma is found.
    public var lastName: String {
        guard let commaRange = name.range(of: ", ") else {
            // No ", " separator -- check for bare comma
            if let commaIndex = name.firstIndex(of: ",") {
                return String(name[name.startIndex..<commaIndex])
                    .trimmingCharacters(in: .whitespaces)
            }
            return name.trimmingCharacters(in: .whitespaces)
        }
        return String(name[name.startIndex..<commaRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
    }

    /// First name parsed from the raw name string.
    ///
    /// For "Moore, John" returns "John".
    /// For "Irby Jr., Almous (Al)" returns "Almous (Al)".
    /// Returns an empty string if no comma is found.
    public var firstName: String {
        guard let commaRange = name.range(of: ", ") else {
            // No ", " separator -- check for bare comma
            if let commaIndex = name.firstIndex(of: ",") {
                let afterComma = name.index(after: commaIndex)
                return String(name[afterComma...])
                    .trimmingCharacters(in: .whitespaces)
            }
            return ""
        }
        return String(name[commaRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
    }

    /// Display name in "First Last" order.
    ///
    /// For "Moore, John" returns "John Moore".
    /// For "Irby Jr., Almous (Al)" returns "Almous (Al) Irby Jr.".
    public var displayName: String {
        let first = firstName
        let last = lastName
        if first.isEmpty { return last }
        if last.isEmpty { return first }
        return "\(first) \(last)"
    }
}
