// EFF.swift
// ARINC633Kit
//
// Electronic Flight Folder (EFF) container model.
// Based on EFF.xsd -- supports EFUSUB (ground to aircraft) and EFDREP (aircraft to ground).
// Contains recursive subfolder structure with documents, topics, and signatures.

import Foundation

// MARK: - EFF Container

/// Electronic Flight Folder message.
///
/// The EFF is a container for organizing flight documents into a hierarchical
/// folder structure. Each document has metadata (type, status, signature requirements)
/// and references an external file in the EFF package.
public struct EFF: Sendable, Equatable {
    /// Standard ARINC 633 header.
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context.
    public let supplementaryHeader: SupplementaryHeader

    /// Root folder containing all subfolders and documents.
    public let rootFolder: EFFFolder

    /// Whether this is a full package or partial update.
    public let fullPackage: Bool

    /// Source system name (required by spec).
    public let source: String?

    /// Operational step (e.g., initial, flight acceptance, post flight report).
    public let operationalStep: String?

    /// Originator identification (pilot name, staff number, etc.).
    public let originator: String?

    /// Direction of the EFF message.
    public let direction: EFFDirection

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                rootFolder: EFFFolder = EFFFolder(),
                fullPackage: Bool = false,
                source: String? = nil,
                operationalStep: String? = nil,
                originator: String? = nil,
                direction: EFFDirection = .submission) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.rootFolder = rootFolder
        self.fullPackage = fullPackage
        self.source = source
        self.operationalStep = operationalStep
        self.originator = originator
        self.direction = direction
    }
}

// MARK: - EFF Direction

/// Direction of the EFF message.
public enum EFFDirection: String, Sendable, Equatable {
    /// EFUSUB: Ground to aircraft submission.
    case submission = "EFUSUB"

    /// EFDREP: Aircraft to ground report.
    case report = "EFDREP"
}

// MARK: - EFF Folder

/// A subfolder within the EFF hierarchy.
///
/// Folders can contain nested subfolders (recursive) and documents.
/// Each folder has a title and optional constraint/template information.
public struct EFFFolder: Sendable, Equatable {
    /// Folder title (e.g., "_Root_Folder_", "Flight plan", "METEO").
    public let title: String

    /// Nested subfolders (recursive structure).
    public let subfolders: [EFFFolder]

    /// Documents contained in this folder.
    public let documents: [EFFDocument]

    /// Topics associated with this folder.
    public let topics: [String]

    /// Whether documents in this folder are activatable.
    public let documentActivatable: Bool?

    /// Active document ID within this folder.
    public let activeDocument: String?

    /// Whether this folder is mandatory.
    public let mandatory: Bool?

    /// Constraint type for the folder.
    public let constraint: String?

    /// Change status (New, Unchanged, Revised, Deactivated).
    public let changed: String?

    public init(title: String = "",
                subfolders: [EFFFolder] = [],
                documents: [EFFDocument] = [],
                topics: [String] = [],
                documentActivatable: Bool? = nil,
                activeDocument: String? = nil,
                mandatory: Bool? = nil,
                constraint: String? = nil,
                changed: String? = nil) {
        self.title = title
        self.subfolders = subfolders
        self.documents = documents
        self.topics = topics
        self.documentActivatable = documentActivatable
        self.activeDocument = activeDocument
        self.mandatory = mandatory
        self.constraint = constraint
        self.changed = changed
    }
}

// MARK: - EFF Document

/// A document within an EFF folder.
///
/// Contains metadata about the document file, including its type (MIME),
/// status, signature requirements, and timing information.
public struct EFFDocument: Sendable, Equatable {
    /// Unique document identifier within the EFF lifecycle.
    public let id: String

    /// Document title (must be unique within its topic).
    public let title: String

    /// MIME type of the document (e.g., "text/xml", "application/pdf").
    public let mimeType: String

    /// Filename of the document (no path information).
    public let file: String

    /// Topic associated with this document.
    public let topic: String?

    /// Whether this document is mandatory.
    public let mandatory: Bool?

    /// Constraint requirement (None, Check, Sign).
    public let constraint: String?

    /// Document status (None, Read, Check, Signed).
    public let status: String?

    /// Change status (New, Unchanged, Revised, Deactivated).
    public let changed: String?

    /// Whether document transfer is pending.
    public let transferPending: Bool?

    /// Timestamp when document was published.
    public let updateDateTime: String?

    /// Original creation timestamp.
    public let originalDateTime: String?

    /// Author profile (e.g., "dispatcher").
    public let authorProfile: String?

    /// Author name.
    public let authorName: String?

    /// Whether only the captain can view this document.
    public let captainOnly: Bool?

    /// Priority level (string, typically "0").
    public let priority: String?

    /// Display model hint (e.g., "ETOPSlayout").
    public let displayModel: String?

    /// Signatures attached to this document.
    public let signatures: [EFFSignature]

    public init(id: String = "",
                title: String = "",
                mimeType: String = "",
                file: String = "",
                topic: String? = nil,
                mandatory: Bool? = nil,
                constraint: String? = nil,
                status: String? = nil,
                changed: String? = nil,
                transferPending: Bool? = nil,
                updateDateTime: String? = nil,
                originalDateTime: String? = nil,
                authorProfile: String? = nil,
                authorName: String? = nil,
                captainOnly: Bool? = nil,
                priority: String? = nil,
                displayModel: String? = nil,
                signatures: [EFFSignature] = []) {
        self.id = id
        self.title = title
        self.mimeType = mimeType
        self.file = file
        self.topic = topic
        self.mandatory = mandatory
        self.constraint = constraint
        self.status = status
        self.changed = changed
        self.transferPending = transferPending
        self.updateDateTime = updateDateTime
        self.originalDateTime = originalDateTime
        self.authorProfile = authorProfile
        self.authorName = authorName
        self.captainOnly = captainOnly
        self.priority = priority
        self.displayModel = displayModel
        self.signatures = signatures
    }
}

// MARK: - EFF Signature

/// Signature information for a document.
public struct EFFSignature: Sendable, Equatable {
    /// Signature type (SHA, MD5, RSA, FLAG).
    public let type: String

    /// Timestamp of the signature.
    public let timestamp: String

    /// Whether this is a legal or simple signature.
    public let isLegal: Bool

    /// User ID (for simple signatures, deprecated in spec).
    public let userID: String?

    /// Digest value.
    public let digest: String?

    /// Certificate (for legal signatures, Base64 encoded).
    public let certificate: String?

    public init(type: String = "SHA",
                timestamp: String = "",
                isLegal: Bool = false,
                userID: String? = nil,
                digest: String? = nil,
                certificate: String? = nil) {
        self.type = type
        self.timestamp = timestamp
        self.isLegal = isLegal
        self.userID = userID
        self.digest = digest
        self.certificate = certificate
    }
}
