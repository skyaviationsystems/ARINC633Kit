// GeneralError.swift
// ARINC633Kit
//
// Typed model for the General Error Indication message.
// Source: ERR.xsd (root <GERIND>), shared GeneralErrorType from m633common.xsd.
//
// Structure: <GERIND> -> <M633Header>, optional <M633SupplementaryHeader>, and a
// single required <Error> element. The <Error> element is attribute-only and carries
// the error report: which application/service/element triggered the error, the error
// classification, application-defined error data, and a retry hint.

import Foundation

/// A parsed General Error Indication (`<GERIND>`): a report describing an error
/// triggered by a previously received element, as defined by the General Error Service.
public struct GeneralError: Sendable, Equatable {
    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Optional supplementary header (`<M633SupplementaryHeader>`, minOccurs=0).
    public let supplementaryHeader: SupplementaryHeader

    /// The error report (`<Error>`, type `GeneralErrorType`).
    ///
    /// The schema declares exactly one `<Error>` element, so this is non-optional in
    /// well-formed documents; it defaults to an empty report when absent.
    public var error: GeneralErrorReport

    /// Unrecognized child elements preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                error: GeneralErrorReport = GeneralErrorReport(),
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.error = error
        self.extensions = extensions
    }
}

/// A single error report (`<Error>`, `GeneralErrorType` in m633common.xsd).
///
/// All fields originate from attributes on the `<Error>` element. The combination of
/// `erroneousService`, `erroneousElement`, and `erroneousVersion` identifies the
/// offending element that triggered the error; `errorClass` / `errorType` classify it
/// per the General Error Service tables; `errorData` is application-interpreted.
public struct GeneralErrorReport: Sendable, Equatable {
    /// SMI of the application that generated this error (`@erroneousSMI`, optional, 3-char).
    public var erroneousSMI: String?

    /// Service that triggered the error (`@erroneousService`, required, 3-char).
    public var erroneousService: String?

    /// Element whose reception triggered the error (`@erroneousElement`, required, 3-char).
    public var erroneousElement: String?

    /// Version of the offending element (`@erroneousVersion`, required, non-negative integer).
    public var erroneousVersion: Int?

    /// Error class (`@errorClass`, optional). See the General Error Service "Error Classes" table.
    public var errorClass: Int?

    /// Error type (`@errorType`, optional). See the General Error Service "Error Types" table.
    public var errorType: Int?

    /// Application-interpreted error data (`@errorData`, optional, min length 1).
    public var errorData: String?

    /// Retry hint (`@tryAgain`, optional boolean): `true` if the receiver may retry sending
    /// the offending element, `false` if it should not, `nil` if unspecified.
    public var tryAgain: Bool?

    public init(erroneousSMI: String? = nil,
                erroneousService: String? = nil,
                erroneousElement: String? = nil,
                erroneousVersion: Int? = nil,
                errorClass: Int? = nil,
                errorType: Int? = nil,
                errorData: String? = nil,
                tryAgain: Bool? = nil) {
        self.erroneousSMI = erroneousSMI
        self.erroneousService = erroneousService
        self.erroneousElement = erroneousElement
        self.erroneousVersion = erroneousVersion
        self.errorClass = errorClass
        self.errorType = errorType
        self.errorData = errorData
        self.tryAgain = tryAgain
    }
}
