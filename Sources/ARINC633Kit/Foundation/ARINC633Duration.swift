// ARINC633Duration.swift
// ARINC633Kit
//
// ISO 8601 duration parser using Swift regex.
// Handles: PT8H27M, PT0H25M, PT00H04M, PT17M58S, PT0M, PT8H

import Foundation

/// Parsed ISO 8601 duration (e.g., "PT8H27M", "PT17M58S", "PT0M").
public struct ARINC633Duration: Sendable, Equatable {
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    /// Total duration in minutes (truncates seconds).
    public var totalMinutes: Int { hours * 60 + minutes }

    /// Total duration in seconds.
    public var totalSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    /// Parses an ISO 8601 duration string.
    ///
    /// Supported formats:
    /// - `PT8H27M` (hours and minutes)
    /// - `PT0H25M` (zero hours, minutes)
    /// - `PT00H04M` (zero-padded hours)
    /// - `PT17M58S` (minutes and seconds)
    /// - `PT0M` (zero minutes)
    /// - `PT8H` (hours only)
    /// - `PT8H27M30S` (hours, minutes, and seconds)
    ///
    /// Returns nil for invalid input.
    public init?(from string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("PT") else { return nil }

        let hmsPattern = /PT(\d+)H(\d+)M(\d+)S/
        let hmPattern = /PT(\d+)H(\d+)M/
        let msPattern = /PT(\d+)M(\d+)S/
        let hOnlyPattern = /PT(\d+)H/
        let mOnlyPattern = /PT(\d+)M/
        let sOnlyPattern = /PT(\d+)S/

        if let match = trimmed.firstMatch(of: hmsPattern) {
            self.hours = Int(match.1) ?? 0
            self.minutes = Int(match.2) ?? 0
            self.seconds = Int(match.3) ?? 0
        } else if let match = trimmed.firstMatch(of: hmPattern) {
            self.hours = Int(match.1) ?? 0
            self.minutes = Int(match.2) ?? 0
            self.seconds = 0
        } else if let match = trimmed.firstMatch(of: msPattern) {
            self.hours = 0
            self.minutes = Int(match.1) ?? 0
            self.seconds = Int(match.2) ?? 0
        } else if let match = trimmed.firstMatch(of: hOnlyPattern) {
            self.hours = Int(match.1) ?? 0
            self.minutes = 0
            self.seconds = 0
        } else if let match = trimmed.firstMatch(of: mOnlyPattern) {
            self.hours = 0
            self.minutes = Int(match.1) ?? 0
            self.seconds = 0
        } else if let match = trimmed.firstMatch(of: sOnlyPattern) {
            self.hours = 0
            self.minutes = 0
            self.seconds = Int(match.1) ?? 0
        } else {
            return nil
        }
    }

    /// Direct initialization with components.
    public init(hours: Int = 0, minutes: Int = 0, seconds: Int = 0) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}
