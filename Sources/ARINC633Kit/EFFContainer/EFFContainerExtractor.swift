// EFFContainerExtractor.swift
// ARINC633Kit
//
// Extracts the contents of an ARINC 633-5 EFF container (double-nested ZIP).
// The outer ZIP contains a .lst manifest and a .dat inner ZIP with all XML/PDF files.

import Foundation
import ZIPFoundation

// MARK: - Extraction Result

/// The result of extracting an EFF container.
///
/// Contains the parsed manifest, the raw eff.xml data, and dictionaries
/// of XML and PDF files keyed by filename.
public struct EFFExtractionResult: Sendable {
    /// Parsed .lst manifest with file checksums.
    public let manifest: EFFManifest

    /// Raw eff.xml data (the ARINC 633 EFF message XML).
    public let effXML: Data

    /// XML files extracted from the .dat archive, keyed by filename.
    public let xmlFiles: [String: Data]

    /// PDF files extracted from the .dat archive, keyed by filename.
    public let pdfFiles: [String: Data]

    /// All files extracted from the .dat archive, keyed by filename.
    public let allFiles: [String: Data]

    public init(manifest: EFFManifest, effXML: Data,
                xmlFiles: [String: Data], pdfFiles: [String: Data],
                allFiles: [String: Data]) {
        self.manifest = manifest
        self.effXML = effXML
        self.xmlFiles = xmlFiles
        self.pdfFiles = pdfFiles
        self.allFiles = allFiles
    }
}

// MARK: - EFF Manifest

/// Parsed .lst manifest from the EFF container.
///
/// Contains a global checkcode and per-file MD5 hashes for integrity verification.
public struct EFFManifest: Sendable, Equatable {
    /// Global checkcode for the entire package (Base64-encoded MD5).
    public let checkcode: String

    /// Per-file hashes listed in the manifest.
    public let files: [HashedFile]

    public init(checkcode: String = "", files: [HashedFile] = []) {
        self.checkcode = checkcode
        self.files = files
    }

    /// A file entry in the manifest with its integrity hash.
    public struct HashedFile: Sendable, Equatable {
        /// Filename referenced by the hash (e.g., "ofp.pdf").
        public let href: String

        /// Base64-encoded MD5 hash of the file contents.
        public let hash: String

        public init(href: String, hash: String) {
            self.href = href
            self.hash = hash
        }
    }
}

// MARK: - Errors

/// Errors that can occur during EFF container extraction.
public enum EFFContainerError: Error, Sendable {
    /// The outer ZIP archive could not be opened.
    case invalidOuterArchive

    /// No .lst manifest file found in the outer archive.
    case missingManifest

    /// No .dat data file found in the outer archive.
    case missingDataFile

    /// The inner .dat ZIP archive could not be opened.
    case invalidInnerArchive

    /// No eff.xml found inside the .dat archive.
    case missingEFFXML

    /// Failed to extract a specific file from the archive.
    case extractionFailed(String)

    /// The .lst manifest XML could not be parsed.
    case manifestParseError(String)
}

// MARK: - Extractor

/// Extracts the contents of an EFF container (double-nested ZIP archive).
///
/// EFF files follow the ARINC 633-5 packaging format:
/// ```
/// EFF (ZIP)
/// +-- .lst   -> XML manifest with file hashes
/// +-- .dat   -> ZIP containing all XML and PDF files
/// ```
///
/// Usage:
/// ```swift
/// let data = try Data(contentsOf: effFileURL)
/// let result = try EFFContainerExtractor.extract(data: data)
/// // result.xmlFiles["ARINC633-5_FlightPlan.xml"] -> FlightPlan XML data
/// // result.pdfFiles["ofp.pdf"] -> OFP PDF data
/// ```
public enum EFFContainerExtractor {

    /// Extract all files from an EFF container.
    ///
    /// - Parameter data: Raw bytes of the .eff file (outer ZIP)
    /// - Returns: Extraction result with manifest, eff.xml, and all contained files
    /// - Throws: `EFFContainerError` on failure
    public static func extract(data: Data) throws -> EFFExtractionResult {
        // Open outer ZIP
        guard let outerArchive = try? Archive(data: data, accessMode: .read) else {
            throw EFFContainerError.invalidOuterArchive
        }

        // Find .lst and .dat entries
        var lstData: Data?
        var datData: Data?

        for entry in outerArchive {
            let filename = (entry.path as NSString).lastPathComponent
            let ext = (filename as NSString).pathExtension.lowercased()

            if ext == "lst" {
                lstData = try extractEntry(entry, from: outerArchive)
            } else if ext == "dat" {
                datData = try extractEntry(entry, from: outerArchive)
            }
        }

        guard let manifestData = lstData else {
            throw EFFContainerError.missingManifest
        }
        guard let innerZipData = datData else {
            throw EFFContainerError.missingDataFile
        }

        // Parse the .lst manifest
        let manifest = try parseManifest(data: manifestData)

        // Open inner .dat ZIP
        guard let innerArchive = try? Archive(data: innerZipData, accessMode: .read) else {
            throw EFFContainerError.invalidInnerArchive
        }

        // Extract all files from inner archive
        var allFiles: [String: Data] = [:]
        var xmlFiles: [String: Data] = [:]
        var pdfFiles: [String: Data] = [:]
        var effXML: Data?

        for entry in innerArchive {
            guard entry.type == .file else { continue }

            let filename = (entry.path as NSString).lastPathComponent
            guard !filename.isEmpty else { continue }

            let fileData = try extractEntry(entry, from: innerArchive)
            allFiles[filename] = fileData

            let ext = (filename as NSString).pathExtension.lowercased()
            if ext == "xml" {
                xmlFiles[filename] = fileData
                if filename.lowercased() == "eff.xml" {
                    effXML = fileData
                }
            } else if ext == "pdf" {
                pdfFiles[filename] = fileData
            }
        }

        guard let effXMLData = effXML else {
            throw EFFContainerError.missingEFFXML
        }

        return EFFExtractionResult(
            manifest: manifest,
            effXML: effXMLData,
            xmlFiles: xmlFiles,
            pdfFiles: pdfFiles,
            allFiles: allFiles
        )
    }

    // MARK: - Private Helpers

    /// Extract the data for a single archive entry.
    private static func extractEntry(_ entry: Entry, from archive: Archive) throws -> Data {
        var result = Data()
        _ = try archive.extract(entry) { chunk in
            result.append(chunk)
        }
        return result
    }

    /// Parse the .lst manifest XML into an EFFManifest.
    private static func parseManifest(data: Data) throws -> EFFManifest {
        let parser = ManifestParser()
        return try parser.parse(data: data)
    }
}

// MARK: - Manifest Parser

/// SAX parser for the .lst hashfilelist XML manifest.
///
/// Parses the following structure:
/// ```xml
/// <hashfilelist xmlns="http://aeec.aviation-ia.net/633">
///   <checkcode>87zZzbDbWPvfDim9lpLjLQ==</checkcode>
///   <hashedfile href="ofp.pdf">RZgBdA0xwsIpE7Jr2ubZlw==</hashedfile>
/// </hashfilelist>
/// ```
private final class ManifestParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private var checkcode = ""
    private var files: [EFFManifest.HashedFile] = []
    private var currentText = ""
    private var currentHref: String?
    private var parseError: Error?

    func parse(data: Data) throws -> EFFManifest {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = true
        xmlParser.parse()

        if let error = parseError {
            throw EFFContainerError.manifestParseError(error.localizedDescription)
        }

        return EFFManifest(checkcode: checkcode, files: files)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "hashedfile" {
            currentHref = attributeDict["href"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "checkcode":
            checkcode = trimmed

        case "hashedfile":
            if let href = currentHref, !href.isEmpty {
                files.append(EFFManifest.HashedFile(href: href, hash: trimmed))
            }
            currentHref = nil

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }
}
