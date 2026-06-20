// ARINC633Parser.swift
// ARINC633Kit
//
// Unified entry point for ARINC 633 XML parsing.
// Detects message type from root element, dispatches to type-specific parsers.

import Foundation

/// Unified entry point for parsing any ARINC 633-4 XML message.
///
/// Usage:
/// ```swift
/// let parser = ARINC633Parser()
/// let message = try parser.parse(data: xmlData)
/// ```
///
/// The parser performs two passes:
/// 1. Quick root element detection via `RootElementDetector`
/// 2. Registry lookup of a handler for that root element. If none is registered,
///    the document is preserved as `.captured(CapturedElement)` — never dropped.
///
/// Dispatch is driven entirely by an `ARINC633MessageRegistry`. The default is
/// `.standard` (all built-in types); pass a customized registry to add airline/vendor
/// message types (see `ARINC633MessageRegistry.registering(_:_:)`).
public final class ARINC633Parser: Sendable {

    /// The registry used to dispatch a detected root element to a handler.
    public let registry: ARINC633MessageRegistry

    /// Create a parser. Defaults to `.standard`, covering all built-in message types.
    public init(registry: ARINC633MessageRegistry = .standard) {
        self.registry = registry
    }

    /// Parse an ARINC 633 XML document and return the typed message.
    ///
    /// - Parameter data: Raw XML data
    /// - Returns: The parsed message type, or `.captured` for an unregistered root
    /// - Throws: `ARINC633ParseError` on empty input or malformed XML
    public func parse(data: Data) throws -> ARINC633Message {
        // First pass: detect root element name.
        let detector = RootElementDetector()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = detector
        xmlParser.shouldProcessNamespaces = true
        xmlParser.parse()

        guard let rootElement = detector.rootElement else {
            // No root element at all: empty data, non-XML bytes, or truncated prologue.
            if let error = xmlParser.parserError {
                throw ARINC633ParseError.xmlParserError(error.localizedDescription)
            }
            throw ARINC633ParseError.emptyDocument
        }

        // Second pass: dispatch via the registry, else capture the whole tree.
        if let handler = registry.handler(for: rootElement) {
            return try handler(data)
        }
        let captured = try GenericElementParser().parse(data: data)
        return .captured(captured)
    }
}

// MARK: - Root Element Detector

/// Lightweight SAX parser that captures the root element name and stops.
final class RootElementDetector: NSObject, XMLParserDelegate, @unchecked Sendable {
    /// The detected root element name.
    var rootElement: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if rootElement == nil {
            rootElement = elementName
            parser.abortParsing()
        }
    }
}
