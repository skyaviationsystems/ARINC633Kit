// SAXParserEngine.swift
// ARINC633Kit
//
// Base SAX parser class providing element stack management and character buffer.
// All domain parsers inherit from this class.

import Foundation

/// Base class for all ARINC 633 SAX parsers.
///
/// Provides:
/// - Element stack tracking for disambiguation
/// - Character buffer accumulation (handles fragmented text callbacks)
/// - Convenience accessors for parent/grandparent/greatGrandparent elements
/// - Stack containment check
///
/// Subclasses override `handleEndElement(_:text:attributes:)` to process content.
open class SAXParserEngine: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Stack of currently open element names (from root to current).
    public var elementStack: [String] = []

    /// Accumulated text content for the current element.
    public var characterBuffer: String = ""

    /// Attributes of the current innermost element.
    public var currentAttributes: [String: String] = [:]

    /// Parent of current element (stack[-2]), or empty string if not deep enough.
    public var parent: String {
        elementStack.count >= 2 ? elementStack[elementStack.count - 2] : ""
    }

    /// Grandparent of current element (stack[-3]), or empty string.
    public var grandparent: String {
        elementStack.count >= 3 ? elementStack[elementStack.count - 3] : ""
    }

    /// Great-grandparent of current element (stack[-4]), or empty string.
    public var greatGrandparent: String {
        elementStack.count >= 4 ? elementStack[elementStack.count - 4] : ""
    }

    /// Check if any ancestor in the stack matches the given element name.
    public func stackContains(_ element: String) -> Bool {
        elementStack.contains(element)
    }

    // MARK: - XMLParserDelegate

    open func parser(_ parser: XMLParser, didStartElement elementName: String,
                     namespaceURI: String?, qualifiedName: String?,
                     attributes attributeDict: [String: String] = [:]) {
        elementStack.append(elementName)
        characterBuffer = ""
        currentAttributes = attributeDict
        handleStartElement(elementName, attributes: attributeDict)
    }

    open func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    open func parser(_ parser: XMLParser, didEndElement elementName: String,
                     namespaceURI: String?, qualifiedName: String?) {
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        handleEndElement(elementName, text: text)
        if let last = elementStack.last, last == elementName {
            elementStack.removeLast()
        }
    }

    // MARK: - Override Points

    /// Called when an element opens. Override in subclasses for start-element handling.
    open func handleStartElement(_ elementName: String, attributes: [String: String]) {
        // Subclass override point
    }

    /// Called when an element closes with its accumulated text content.
    /// Override in subclasses for content processing.
    open func handleEndElement(_ elementName: String, text: String) {
        // Subclass override point
    }

    // MARK: - Parsing Helpers

    /// Run the XML parser with this engine as delegate.
    public func run(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = true
        xmlParser.shouldReportNamespacePrefixes = false

        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                throw ARINC633ParseError.xmlParserError(error.localizedDescription)
            }
            throw ARINC633ParseError.xmlParserError("Unknown parse error")
        }
    }
}
