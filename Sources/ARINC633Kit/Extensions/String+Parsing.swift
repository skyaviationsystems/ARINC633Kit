// String+Parsing.swift
// ARINC633Kit
//
// String parsing helpers for XML text content conversion.

import Foundation

extension String {
    /// Returns the string with whitespace trimmed, or nil if the result is empty.
    public var trimmedOrNil: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Safely parses the string as a Double, returning nil on failure.
    public var toDouble: Double? {
        Double(self.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Safely parses the string as an Int, returning nil on failure.
    public var toInt: Int? {
        Int(self.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
