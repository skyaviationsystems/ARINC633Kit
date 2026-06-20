// ARINCCoordinate.swift
// ARINC633Kit
//
// Coordinate type with arc-seconds to decimal degrees conversion.
// ARINC 633 coordinates are in arc-seconds:
//   Latitude range: [-324000, 324000] (90 degrees * 3600)
//   Longitude range: [-648000, 648000] (180 degrees * 3600)

import Foundation

/// Geographic coordinate in decimal degrees.
///
/// ARINC 633 XML provides coordinates in arc-seconds. Use the
/// `init(latitudeArcSeconds:longitudeArcSeconds:)` initializer for conversion.
public struct ARINCCoordinate: Sendable, Equatable {
    /// Latitude in decimal degrees (positive = North, negative = South).
    public let latitude: Double

    /// Longitude in decimal degrees (positive = East, negative = West).
    public let longitude: Double

    /// Convert from ARINC 633 arc-seconds to decimal degrees.
    ///
    /// Example: Miami airport
    /// - latitude="92862.0" => 92862.0 / 3600.0 = 25.795 (25.8N)
    /// - longitude="-289044.0" => -289044.0 / 3600.0 = -80.29 (-80.3W)
    public init(latitudeArcSeconds: Double, longitudeArcSeconds: Double) {
        self.latitude = latitudeArcSeconds / 3600.0
        self.longitude = longitudeArcSeconds / 3600.0
    }

    /// Direct initialization with decimal degrees.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
