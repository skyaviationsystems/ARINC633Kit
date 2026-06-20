// Remarks.swift
// ARINC633Kit
//
// Operational remarks from <Remarks>.
// Remarks are stored as a [String] array on the FlightPlan model directly.
// This file provides a namespace placeholder for any future structured remark types.

import Foundation

/// Structured remark with type and text content.
public struct FlightPlanRemark: Sendable, Equatable {
    /// Remark type (e.g., "general", "AcftIdleFactor").
    public let remarkType: String

    /// Remark text content.
    public let text: String

    public init(remarkType: String, text: String) {
        self.remarkType = remarkType
        self.text = text
    }
}
