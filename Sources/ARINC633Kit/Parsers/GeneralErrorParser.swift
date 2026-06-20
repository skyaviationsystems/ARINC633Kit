// GeneralErrorParser.swift
// ARINC633Kit
//
// Parser for the General Error Indication message (root <GERIND>, ERR.xsd).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, the single <Error> element's attributes are mapped to a
// typed GeneralErrorReport, and any unrecognized children are swept into the model's
// `extensions` bag.

import Foundation

/// Parses a `<GERIND>` document into a `GeneralError`.
public final class GeneralErrorParser: Sendable {

    public init() {}

    /// Parse General Error Indication XML into a typed `GeneralError`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> GeneralError {
        let root = try GenericElementParser().parse(data: data)

        var message = GeneralError(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader()
        )

        if let errorEl = root.firstDescendant(named: "Error") {
            message.error = Self.report(from: errorEl)
        }

        // Preserve any unmodeled top-level payload children.
        message.extensions = root.payloadChildren.filter { $0.name != "Error" }
        return message
    }

    /// Map an `<Error>` element's attributes to a `GeneralErrorReport`.
    private static func report(from el: CapturedElement) -> GeneralErrorReport {
        GeneralErrorReport(
            erroneousSMI: el.attribute("erroneousSMI"),
            erroneousService: el.attribute("erroneousService"),
            erroneousElement: el.attribute("erroneousElement"),
            erroneousVersion: el.attribute("erroneousVersion").flatMap { Int($0) },
            errorClass: el.attribute("errorClass").flatMap { Int($0) },
            errorType: el.attribute("errorType").flatMap { Int($0) },
            errorData: el.attribute("errorData"),
            tryAgain: el.attribute("tryAgain").map { $0 == "true" || $0 == "1" }
        )
    }
}
