// NOTAMBriefingParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633 NOTAMBriefing message type.
// Extracts all NOTAM items with severity, Q-codes, altitudes, and briefing sections.

import Foundation

/// SAX parser for ARINC 633 NOTAMBriefing message type.
///
/// Handles large briefing files (1MB+, hundreds of NOTAMs) efficiently via streaming SAX.
/// Parses M633Header, M633SupplementaryHeader, and each `<NOTAM>` element with all child data.
final class NOTAMBriefingParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = NOTAMBriefing()

    // MARK: - Header Builder State

    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var headerMessageSequence: String?

    // Supplementary header builders
    private var inSuppHeader = false
    private var suppFlightAirlineCode = ""
    private var suppFlightNumber = ""
    private var suppFlightIdentifier: String?
    private var suppCommercialFlightNumber: String?
    private var suppDepartureICAO = ""
    private var suppDepartureIATA: String?
    private var suppArrivalICAO = ""
    private var suppArrivalIATA: String?
    private var suppFlightOriginDate: String?
    private var suppScheduledDeparture: String?
    private var suppAircraftRegistration = ""
    private var suppAircraftType: String?
    private var suppAircraftSubType: String?

    // MARK: - NOTAM Builder State

    private var inNOTAM = false
    private var currentNOTAM = NOTAMItem()
    private var notamTextParagraphs: [String] = []
    private var remarkParagraphs: [String] = []

    // MARK: - Section Tracking

    private var inUpperAltitude = false
    private var inLowerAltitude = false
    private var inRemark = false

    // MARK: - Public Interface

    /// Parse NOTAMBriefing XML data.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: Fully parsed `NOTAMBriefing`
    /// - Throws: `ARINC633ParseError` on parse failure
    func parse(data: Data) throws -> NOTAMBriefing {
        try run(data: data)
        finalizeHeaders()
        try captureExtensions(from: data)
        return result
    }

    /// Local names this parser models as direct children of `<NOTAMBriefing>`.
    /// Anything else (vendor `xs:any`-style extensions) is preserved in
    /// `NOTAMBriefing.extensions`.
    private static let modeledBriefingChildren: Set<String> = [
        "M633Header", "M633SupplementaryHeader", "NOTAMs", "NOTAM"
    ]

    /// Local names this parser models as direct children of a `<NOTAM>`. The schema
    /// terminates the NOTAM content model with `<xs:any namespace="##other"/>`, so any
    /// other child (Location/Geography/AltitudeLimit/Countries/Routes/Waypoints/…) is
    /// preserved in that NOTAM's `extensions` bag rather than dropped.
    private static let modeledNOTAMChildren: Set<String> = [
        "NOTAMSubjects", "BriefingSections", "NOTAMText", "Keys",
        "Altitudes", "ICAONOTAMInformation", "Remark"
    ]

    /// Second pass: walk the full document tree and append every direct child our SAX
    /// pass does not model — at the briefing level and inside each `<NOTAM>` — to the
    /// corresponding `extensions` bag. NOTAMs are matched to parsed items by document
    /// order. This guarantees nothing well-formed is silently discarded.
    private func captureExtensions(from data: Data) throws {
        let tree = try GenericElementParser().parse(data: data)

        // (a) Unmodeled direct children of <NOTAMBriefing>.
        for child in tree.children where !Self.modeledBriefingChildren.contains(child.name) {
            result.extensions.append(child)
        }

        // (b) For each <NOTAM> (in document order), unmodeled direct children.
        var notamElements: [CapturedElement] = []
        collectNOTAMElements(in: tree, into: &notamElements)
        for (index, notamEl) in notamElements.enumerated() where index < result.notams.count {
            let extras = notamEl.children.filter { !Self.modeledNOTAMChildren.contains($0.name) }
            if !extras.isEmpty {
                result.notams[index].extensions.append(contentsOf: extras)
            }
        }
    }

    /// Depth-first collection of `<NOTAM>` elements in document order.
    private func collectNOTAMElements(in element: CapturedElement,
                                      into out: inout [CapturedElement]) {
        for child in element.children {
            if child.name == "NOTAM" {
                out.append(child)
            } else {
                collectNOTAMElements(in: child, into: &out)
            }
        }
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "NOTAMBriefing":
            result.briefingType = attributes["briefingType"]
            result.creationTime = attributes["creationTime"]
            result.fullPackage = attributes["fullPackage"] == "true"

        case "M633Header":
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""
            headerMessageSequence = attributes["messageSequence"]

        case "M633SupplementaryHeader":
            inSuppHeader = true

        case "Flight":
            if inSuppHeader {
                suppFlightOriginDate = attributes["flightOriginDate"]
                suppScheduledDeparture = attributes["scheduledTimeOfDeparture"]
            }

        case "FlightNumber":
            if inSuppHeader && !inNOTAM {
                suppFlightAirlineCode = attributes["airlineIATACode"] ?? attributes["airlineICAOCode"] ?? ""
                suppFlightNumber = attributes["number"] ?? ""
            }

        case "Aircraft":
            if inSuppHeader && !inNOTAM {
                suppAircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "AircraftModel":
            if inSuppHeader && !inNOTAM {
                suppAircraftSubType = attributes["airlineSpecificSubType"]
            }

        case "NOTAM":
            inNOTAM = true
            currentNOTAM = NOTAMItem()
            notamTextParagraphs = []
            remarkParagraphs = []
            inRemark = false

            // Capture all NOTAM element attributes
            currentNOTAM.issuer = attributes["issuer"]
            currentNOTAM.source = attributes["source"]
            currentNOTAM.serial = attributes["serial"]
            currentNOTAM.series = attributes["series"]
            currentNOTAM.year = attributes["year"]
            currentNOTAM.startValidTime = attributes["startValidTime"]
            currentNOTAM.endValidTime = attributes["endValidTime"]
            currentNOTAM.creationTime = attributes["creationTime"]
            currentNOTAM.endValidTimeQualifier = attributes["endValidTimeQualifier"]
            currentNOTAM.issuerType = attributes["issuerType"]
            currentNOTAM.revisionTime = attributes["revisionTime"]
            currentNOTAM.sequence = attributes["sequence"].flatMap { Int($0) }
            // Additional NOTAM attributes (@priority default 3, @consideredInFlightPlan,
            // @startApplicabilityTime, @endApplicabilityTime).
            currentNOTAM.priority = attributes["priority"].flatMap { Int($0) }
            currentNOTAM.consideredInFlightPlan = attributes["consideredInFlightPlan"].map { $0 == "true" || $0 == "1" }
            currentNOTAM.startApplicabilityTime = attributes["startApplicabilityTime"]
            currentNOTAM.endApplicabilityTime = attributes["endApplicabilityTime"]

        case "Airspace":
            // Affected airspace key — ICAO is the `airspaceICAOCode` attribute.
            if inNOTAM, stackContains("Keys"), let icao = attributes["airspaceICAOCode"], !icao.isEmpty {
                currentNOTAM.airspaces.append(icao)
            }

        case "ICAONOTAMInformation":
            if inNOTAM {
                currentNOTAM.qcode1 = attributes["qcode1"]
                currentNOTAM.qcode2 = attributes["qcode2"]
                currentNOTAM.trafficIndicator = attributes["trafficIndicator"]
                currentNOTAM.scope = attributes["scope"]
                currentNOTAM.purpose = attributes["purpose"]
                currentNOTAM.fIR = attributes["fIR"]
                currentNOTAM.lowerAlt = attributes["lowerAlt"].flatMap { Int($0) }
                currentNOTAM.upperAlt = attributes["upperAlt"].flatMap { Int($0) }
            }

        case "Remark":
            if inNOTAM { inRemark = true }

        case "Upper":
            if inNOTAM && stackContains("Altitudes") {
                inUpperAltitude = true
                inLowerAltitude = false
            }

        case "Lower":
            if inNOTAM && stackContains("Altitudes") {
                inLowerAltitude = true
                inUpperAltitude = false
            }

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633Header":
            // Header finalized in finalizeHeaders()
            break

        case "M633SupplementaryHeader":
            inSuppHeader = false

        // -- Supplementary header child elements --

        case "FlightIdentifier":
            if inSuppHeader && !inNOTAM {
                suppFlightIdentifier = text.isEmpty ? nil : text
            }

        case "CommercialFlightNumber":
            if inSuppHeader && !inNOTAM {
                suppCommercialFlightNumber = text.isEmpty ? nil : text
            }

        case "AirportICAOCode":
            if inNOTAM {
                // Inside a NOTAM's Keys/Airports/Airport — capture all, keep first as the
                // convenience `airport`.
                if stackContains("Keys") && !text.isEmpty {
                    currentNOTAM.airports.append(text)
                    if currentNOTAM.airport == nil { currentNOTAM.airport = text }
                }
            } else if inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureICAO = text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalICAO = text
                }
            }

        case "AirportIATACode":
            if !inNOTAM && inSuppHeader {
                if stackContains("DepartureAirport") {
                    suppDepartureIATA = text.isEmpty ? nil : text
                } else if stackContains("ArrivalAirport") {
                    suppArrivalIATA = text.isEmpty ? nil : text
                }
            }

        case "AircraftICAOType":
            if inSuppHeader && !inNOTAM {
                suppAircraftType = text.isEmpty ? nil : text
            }

        // -- NOTAM child elements --

        case "NOTAMSubject":
            // The real 633-4 value is a subject keyword (e.g. "Runway", "Airspace"),
            // not a "sev:"-encoded severity. Capture it as a subject.
            if inNOTAM && !text.isEmpty {
                currentNOTAM.subjects.append(text)
            }

        case "BriefingSection":
            if inNOTAM && !text.isEmpty {
                currentNOTAM.briefingSections.append(text)
            }

        case "Text":
            // Both NOTAMText and Remark are TextType (Paragraph/Text). Route by which
            // container we are inside so Remark prose does not bleed into the body text.
            if inNOTAM && stackContains("Paragraph") && !text.isEmpty {
                if inRemark && stackContains("Remark") {
                    remarkParagraphs.append(text)
                } else if stackContains("NOTAMText") {
                    notamTextParagraphs.append(text)
                }
            }

        case "Value":
            // Altitudes/Value is an xs:float with a (default "ft/100") @unit. Preserve
            // both as ARINCAltitude; also keep the truncated Int fields populated for
            // source compatibility. Handles the Upper/Lower bound case and the repeating
            // bare <Altitude> choice (no Upper/Lower) of AltitudeInfoType.
            if inNOTAM && stackContains("Altitudes"), let dbl = Double(text) {
                let unit = currentAttributes["unit"] ?? "ft/100"
                let measured = ARINCAltitude(value: dbl, unit: unit)
                if inUpperAltitude {
                    currentNOTAM.upperAltitudeMeasured = measured
                    currentNOTAM.upperAltitude = Int(dbl)
                } else if inLowerAltitude {
                    currentNOTAM.lowerAltitudeMeasured = measured
                    currentNOTAM.lowerAltitude = Int(dbl)
                } else {
                    // Bare <Altitude><Value/></Altitude> applicability altitude.
                    currentNOTAM.altitudes.append(measured)
                }
            }

        // -- ICAONOTAMInformation decoded items (ItemA/B/C/D/F/G; no ItemE in schema) --

        case "ItemA":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemA = text
            }

        case "ItemB":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemB = text
            }

        case "ItemC":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemC = text
            }

        case "ItemD":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemD = text
            }

        case "ItemF":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemF = text
            }

        case "ItemG":
            if inNOTAM && stackContains("ICAONOTAMInformation") && !text.isEmpty {
                currentNOTAM.itemG = text
            }

        case "Remark":
            inRemark = false

        case "Upper":
            inUpperAltitude = false

        case "Lower":
            inLowerAltitude = false

        case "NOTAM":
            // Finalize current NOTAM
            if !notamTextParagraphs.isEmpty {
                currentNOTAM.text = notamTextParagraphs.joined(separator: "\n")
            }
            if !remarkParagraphs.isEmpty {
                currentNOTAM.remark = remarkParagraphs.joined(separator: "\n")
            }
            result.notams.append(currentNOTAM)
            currentNOTAM = NOTAMItem()
            notamTextParagraphs = []
            remarkParagraphs = []
            inNOTAM = false
            inUpperAltitude = false
            inLowerAltitude = false
            inRemark = false

        default:
            break
        }
    }

    // MARK: - Finalize

    private func finalizeHeaders() {
        result.header = ARINC633Header(
            versionNumber: headerVersionNumber,
            timestamp: headerTimestamp,
            messageSequence: headerMessageSequence
        )
        result.supplementaryHeader = SupplementaryHeader(
            flight: ARINCHeaderFlight(
                airlineCode: suppFlightAirlineCode,
                flightNumber: suppFlightNumber,
                flightIdentifier: suppFlightIdentifier,
                commercialFlightNumber: suppCommercialFlightNumber,
                departure: ARINCHeaderAirport(
                    icaoCode: suppDepartureICAO,
                    iataCode: suppDepartureIATA
                ),
                arrival: ARINCHeaderAirport(
                    icaoCode: suppArrivalICAO,
                    iataCode: suppArrivalIATA
                ),
                scheduledDepartureTime: suppScheduledDeparture,
                flightOriginDate: suppFlightOriginDate
            ),
            aircraft: ARINCHeaderAircraft(
                registration: suppAircraftRegistration,
                aircraftType: suppAircraftType,
                engineType: suppAircraftSubType
            )
        )
    }
}
