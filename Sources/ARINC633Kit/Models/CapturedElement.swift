// CapturedElement.swift
// ARINC633Kit
//
// Schema-agnostic representation of an arbitrary XML element subtree.
// Backs two capture mechanisms required by the kit:
//   1. `.captured` messages — an entire unrecognized root element preserved as a tree.
//   2. The "extensions bag" — unrecognized *child* elements inside a known message,
//      captured so airline/vendor customizations survive instead of being dropped.

import Foundation

/// A structured, schema-agnostic capture of an XML element and its subtree.
///
/// `CapturedElement` lets the kit preserve content it does not model explicitly —
/// either an entire unknown root (surfaced as `ARINC633Message.captured`) or
/// unrecognized children inside an otherwise-typed message (the `extensions` bag on
/// many models). Nothing in a well-formed document is ever silently discarded.
///
/// Query helpers (`first(named:)`, `all(named:)`, `firstDescendant(named:)`,
/// `attribute(_:)`) make captured trees usable without reaching for raw XML.
public struct CapturedElement: Sendable, Equatable {
    /// Local element name (namespaces are processed away — see `SAXParserEngine`).
    public let name: String

    /// Attributes present on this element, keyed by local attribute name.
    public let attributes: [String: String]

    /// Trimmed text content directly owned by this element (excludes child text).
    public var text: String

    /// Direct child elements, in document order.
    public var children: [CapturedElement]

    public init(name: String,
                attributes: [String: String] = [:],
                text: String = "",
                children: [CapturedElement] = []) {
        self.name = name
        self.attributes = attributes
        self.text = text
        self.children = children
    }

    // MARK: - Queries

    /// The value of an attribute by local name, or `nil` if absent.
    public func attribute(_ name: String) -> String? {
        attributes[name]
    }

    /// The first **direct child** with the given local name, or `nil`.
    public func first(named name: String) -> CapturedElement? {
        children.first { $0.name == name }
    }

    /// All **direct children** with the given local name, in document order.
    public func all(named name: String) -> [CapturedElement] {
        children.filter { $0.name == name }
    }

    /// The first element anywhere in the subtree (depth-first, pre-order) whose
    /// local name matches — including `self`. Useful for reaching nested content
    /// without knowing the exact path.
    public func firstDescendant(named name: String) -> CapturedElement? {
        if self.name == name { return self }
        for child in children {
            if let found = child.firstDescendant(named: name) {
                return found
            }
        }
        return nil
    }

    /// Trimmed text of the first direct child with the given name, if any.
    public func text(ofChild name: String) -> String? {
        first(named: name)?.text
    }
}
