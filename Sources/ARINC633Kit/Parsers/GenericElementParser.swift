// GenericElementParser.swift
// ARINC633Kit
//
// Schema-agnostic fallback parser. Captures ANY XML document as a `CapturedElement`
// tree so an unregistered root element is never dropped — it becomes
// `ARINC633Message.captured(...)`.

import Foundation

/// SAX parser that captures an arbitrary XML document into a `CapturedElement` tree.
///
/// Used by `ARINC633Parser` whenever a root element has no registered handler. It is
/// schema-agnostic: every element, attribute, and text node is preserved in document
/// order. Matches the kit-wide convention of namespace processing + local names.
public final class GenericElementParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private var stack: [CapturedElement] = []
    private var root: CapturedElement?

    /// Parse `data` into a captured tree rooted at the document's root element.
    ///
    /// - Throws: `ARINC633ParseError.xmlParserError` on malformed XML,
    ///   `ARINC633ParseError.emptyDocument` if no root element is found.
    public func parse(data: Data) throws -> CapturedElement {
        stack.removeAll()
        root = nil

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

        guard let root else { throw ARINC633ParseError.emptyDocument }
        return root
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        stack.append(CapturedElement(name: elementName, attributes: attributeDict))
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        guard var finished = stack.popLast() else { return }
        finished.text = finished.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if stack.isEmpty {
            root = finished
        } else {
            stack[stack.count - 1].children.append(finished)
        }
    }
}
