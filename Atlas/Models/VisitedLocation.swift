//
//  VisitedLocation.swift
//  Atlas
//

import SwiftUI
import SwiftData
import CoreLocation

@Model
final class VisitedLocation {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var dateVisited: Date? = nil
    /// "trip" = auto-synced from a completed trip | "manual" = user-added
    var source: String = "manual"

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        dateVisited: Date? = nil,
        source: String = "manual"
    ) {
        self.id          = UUID()
        self.name        = name
        self.latitude    = latitude
        self.longitude   = longitude
        self.dateVisited = dateVisited
        self.source      = source
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
