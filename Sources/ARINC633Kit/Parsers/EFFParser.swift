// EFFParser.swift
// ARINC633Kit
//
// SAX parser for ARINC 633-4 Electronic Flight Folder (EFF) messages.
// Handles both EFUSUB (submission) and EFDREP (report) root elements.
// Supports recursive subfolder structure with document metadata.

import Foundation

/// SAX parser for EFF (Electronic Flight Folder) messages.
///
/// Parses the hierarchical folder/document structure using a stack of folder builders
/// to handle recursive SubFolder nesting. Skips binary EFF containers (.eff files
/// that are RAR/ZIP archives).
final class EFFParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var header = ARINC633Header()
    private var supplementaryHeader = SupplementaryHeader()
    private var fullPackage = false
    private var source: String?
    private var operationalStep: String?
    private var originator: String?
    private var direction: EFFDirection = .submission

    // MARK: - Header Builder State

    private var headerVersionNumber = ""
    private var headerTimestamp = ""
    private var flightOriginDate: String?
    private var scheduledDepartureTime: String?
    private var airlineCode = ""
    private var flightNumberStr = ""
    private var flightIdentifier: String?
    private var commercialFlightNumber: String?
    private var departureICAO = ""
    private var departureIATA: String?
    private var arrivalICAO = ""
    private var arrivalIATA: String?
    private var aircraftRegistration = ""
    private var aircraftType: String?

    // MARK: - Folder Stack

    /// Stack of folder builders for recursive subfolder support.
    /// When a SubFolder opens, push a new builder. When it closes, pop and add to parent.
    private var folderStack: [EFFFolderBuilder] = []

    /// The completed root folder.
    private var rootFolder = EFFFolder()

    // MARK: - Document Builder

    private var currentDocument: EFFDocumentBuilder?
    private var currentSignature: EFFSignatureBuilder?
    private var inDocument = false
    private var inSignature = false
    private var inLegalSign = false
    private var inSimpleSign = false

    // MARK: - Section Tracking

    private var inHeader = false
    private var inSupplementaryHeader = false

    // MARK: - Public Parse Method

    /// Parse EFF XML data into an EFF model.
    ///
    /// - Parameter data: Raw XML data (must be valid XML, not a binary .eff archive)
    /// - Returns: Parsed EFF model
    /// - Throws: `ARINC633ParseError` on parse failure
    func parse(data: Data) throws -> EFF {
        // Skip binary EFF containers (RAR/ZIP archives)
        // Check for XML header or UTF-8 BOM
        if data.count >= 4 {
            let prefix = Array(data.prefix(4))
            let isXML = prefix.starts(with: [0x3C, 0x3F]) // <?
                || prefix.starts(with: [0xEF, 0xBB, 0xBF, 0x3C]) // BOM + <
            if !isXML {
                throw ARINC633ParseError.xmlParserError("Binary EFF container (not XML)")
            }
        }

        try run(data: data)

        return EFF(
            header: header,
            supplementaryHeader: supplementaryHeader,
            rootFolder: rootFolder,
            fullPackage: fullPackage,
            source: source,
            operationalStep: operationalStep,
            originator: originator,
            direction: direction
        )
    }

    // MARK: - Start Element

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "EFUSUB":
            direction = .submission
            fullPackage = attributes["fullPackage"] == "true"
            source = attributes["source"]
            operationalStep = attributes["operationalStep"]
            originator = attributes["originator"]

        case "EFDREP":
            direction = .report
            fullPackage = attributes["fullPackage"] == "true"
            source = attributes["source"]
            operationalStep = attributes["operationalStep"]
            originator = attributes["originator"]

        case "M633Header":
            inHeader = true
            headerVersionNumber = attributes["versionNumber"] ?? ""
            headerTimestamp = attributes["timestamp"] ?? ""

        case "M633SupplementaryHeader":
            inSupplementaryHeader = true

        case "Flight":
            if inSupplementaryHeader {
                flightOriginDate = attributes["flightOriginDate"]
                scheduledDepartureTime = attributes["scheduledTimeOfDeparture"]
            }

        case "FlightNumber":
            if inSupplementaryHeader {
                airlineCode = attributes["airlineIATACode"] ?? ""
                flightNumberStr = attributes["number"] ?? ""
            }

        case "Aircraft":
            if inSupplementaryHeader {
                aircraftRegistration = attributes["aircraftRegistration"] ?? ""
            }

        case "SubFolder":
            let builder = EFFFolderBuilder()
            builder.title = attributes["title"] ?? ""
            builder.documentActivatable = attributes["documentActivatable"].flatMap { $0 == "true" ? true : false }
            builder.activeDocument = attributes["activeDocument"]
            builder.mandatory = attributes["mandatory"].flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) }
            builder.constraint = attributes["constraint"] ?? attributes["Constraint"]
            builder.changed = attributes["changed"]
            folderStack.append(builder)

        case "Document":
            let docBuilder = EFFDocumentBuilder()
            docBuilder.id = attributes["id"] ?? ""
            docBuilder.title = attributes["title"] ?? ""
            docBuilder.mimeType = attributes["type"] ?? ""
            docBuilder.file = attributes["file"] ?? ""
            docBuilder.mandatory = attributes["mandatory"].flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) }
            docBuilder.constraint = attributes["Constraint"] ?? attributes["constraint"]
            docBuilder.status = attributes["status"]
            docBuilder.changed = attributes["changed"]
            docBuilder.transferPending = attributes["transferPending"].flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) }
            docBuilder.updateDateTime = attributes["updateDateTime"]
            docBuilder.originalDateTime = attributes["originalDateTime"]
            docBuilder.authorProfile = attributes["authorProfile"]
            docBuilder.authorName = attributes["authorName"]
            docBuilder.captainOnly = attributes["captainOnly"].flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) }
            docBuilder.priority = attributes["priority"]
            docBuilder.displayModel = attributes["displayModel"]
            currentDocument = docBuilder
            inDocument = true

        case "Signature":
            let sigBuilder = EFFSignatureBuilder()
            sigBuilder.timestamp = attributes["timestamp"] ?? ""
            sigBuilder.type = attributes["type"] ?? "SHA"
            currentSignature = sigBuilder
            inSignature = true
            inLegalSign = false
            inSimpleSign = false

        case "LegalSign":
            inLegalSign = true
            inSimpleSign = false

        case "SimpleSign":
            inSimpleSign = true
            inLegalSign = false
            currentSignature?.userID = attributes["userID"]

        case "Topic":
            // Topic is handled on end element for its name attribute
            if let topicName = attributes["name"] {
                if inDocument, let doc = currentDocument {
                    doc.topic = topicName
                } else if let folder = folderStack.last {
                    folder.topics.append(topicName)
                }
            }

        default:
            break
        }
    }

    // MARK: - End Element

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "M633Header":
            inHeader = false
            header = ARINC633Header(
                versionNumber: headerVersionNumber,
                timestamp: headerTimestamp
            )

        case "M633SupplementaryHeader":
            inSupplementaryHeader = false
            let flight = ARINCHeaderFlight(
                airlineCode: airlineCode,
                flightNumber: flightNumberStr,
                flightIdentifier: flightIdentifier,
                commercialFlightNumber: commercialFlightNumber,
                departure: ARINCHeaderAirport(icaoCode: departureICAO, iataCode: departureIATA),
                arrival: ARINCHeaderAirport(icaoCode: arrivalICAO, iataCode: arrivalIATA),
                scheduledDepartureTime: scheduledDepartureTime,
                flightOriginDate: flightOriginDate
            )
            let aircraft = ARINCHeaderAircraft(
                registration: aircraftRegistration,
                aircraftType: aircraftType
            )
            supplementaryHeader = SupplementaryHeader(flight: flight, aircraft: aircraft)

        case "FlightIdentifier":
            if inSupplementaryHeader { flightIdentifier = text.isEmpty ? nil : text }

        case "CommercialFlightNumber":
            if inSupplementaryHeader { commercialFlightNumber = text.isEmpty ? nil : text }

        case "AirportICAOCode":
            if inSupplementaryHeader {
                if stackContains("DepartureAirport") {
                    departureICAO = text
                } else if stackContains("ArrivalAirport") {
                    arrivalICAO = text
                }
            }

        case "AirportIATACode":
            if inSupplementaryHeader {
                if stackContains("DepartureAirport") {
                    departureIATA = text.isEmpty ? nil : text
                } else if stackContains("ArrivalAirport") {
                    arrivalIATA = text.isEmpty ? nil : text
                }
            }

        case "AircraftICAOType":
            if inSupplementaryHeader { aircraftType = text.isEmpty ? nil : text }

        case "SubFolder":
            guard let builder = folderStack.popLast() else { break }
            let folder = builder.build()
            if folderStack.isEmpty {
                // This was the root folder
                rootFolder = folder
            } else {
                // Add as subfolder to parent
                folderStack.last?.subfolders.append(folder)
            }

        case "Document":
            if let docBuilder = currentDocument {
                let doc = docBuilder.build()
                folderStack.last?.documents.append(doc)
            }
            currentDocument = nil
            inDocument = false

        case "Signature":
            if let sigBuilder = currentSignature {
                let sig = sigBuilder.build()
                currentDocument?.signatures.append(sig)
            }
            currentSignature = nil
            inSignature = false
            inLegalSign = false
            inSimpleSign = false

        case "Digest":
            if inSignature {
                currentSignature?.digest = text
            }

        case "Cert":
            if inSignature && inLegalSign {
                currentSignature?.certificate = text
                currentSignature?.isLegal = true
            }

        default:
            break
        }
    }
}

// MARK: - Builder Classes

/// Mutable builder for constructing EFFFolder during SAX parsing.
private final class EFFFolderBuilder {
    var title = ""
    var subfolders: [EFFFolder] = []
    var documents: [EFFDocument] = []
    var topics: [String] = []
    var documentActivatable: Bool?
    var activeDocument: String?
    var mandatory: Bool?
    var constraint: String?
    var changed: String?

    func build() -> EFFFolder {
        EFFFolder(
            title: title,
            subfolders: subfolders,
            documents: documents,
            topics: topics,
            documentActivatable: documentActivatable,
            activeDocument: activeDocument,
            mandatory: mandatory,
            constraint: constraint,
            changed: changed
        )
    }
}

/// Mutable builder for constructing EFFDocument during SAX parsing.
private final class EFFDocumentBuilder {
    var id = ""
    var title = ""
    var mimeType = ""
    var file = ""
    var topic: String?
    var mandatory: Bool?
    var constraint: String?
    var status: String?
    var changed: String?
    var transferPending: Bool?
    var updateDateTime: String?
    var originalDateTime: String?
    var authorProfile: String?
    var authorName: String?
    var captainOnly: Bool?
    var priority: String?
    var displayModel: String?
    var signatures: [EFFSignature] = []

    func build() -> EFFDocument {
        EFFDocument(
            id: id,
            title: title,
            mimeType: mimeType,
            file: file,
            topic: topic,
            mandatory: mandatory,
            constraint: constraint,
            status: status,
            changed: changed,
            transferPending: transferPending,
            updateDateTime: updateDateTime,
            originalDateTime: originalDateTime,
            authorProfile: authorProfile,
            authorName: authorName,
            captainOnly: captainOnly,
            priority: priority,
            displayModel: displayModel,
            signatures: signatures
        )
    }
}

/// Mutable builder for constructing EFFSignature during SAX parsing.
private final class EFFSignatureBuilder {
    var type = "SHA"
    var timestamp = ""
    var isLegal = false
    var userID: String?
    var digest: String?
    var certificate: String?

    func build() -> EFFSignature {
        EFFSignature(
            type: type,
            timestamp: timestamp,
            isLegal: isLegal,
            userID: userID,
            digest: digest,
            certificate: certificate
        )
    }
}
