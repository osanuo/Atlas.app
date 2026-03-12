//
//  WishlistDestination.swift
//  Atlas
//

import SwiftUI
import SwiftData

@Model
final class WishlistDestination {
    var id: UUID = UUID()
    var city: String = ""
    var country: String = ""
    var notes: String = ""
    var imageURL: String = ""
    var imageData: Data? = nil
    var isVisited: Bool = false
    var dateAdded: Date = Date()

    init(
        city: String,
        country: String,
        notes: String = "",
        imageURL: String = "",
        imageData: Data? = nil
    ) {
        self.id        = UUID()
        self.city      = city.uppercased()
        self.country   = country
        self.notes     = notes
        self.imageURL  = imageURL
        self.imageData = imageData
        self.isVisited = false
        self.dateAdded = Date()
    }
}
