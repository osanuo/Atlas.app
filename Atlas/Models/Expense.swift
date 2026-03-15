//
//  Expense.swift
//  Atlas
//

import SwiftUI
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double = 0
    var note: String = ""
    var categoryRaw: String = ItemCategory.restaurants.rawValue
    var date: Date = Date()

    /// Who paid this expense (display name of crew member, empty = unspecified)
    var paidByName: String = ""

    /// Receipt photo stored externally to avoid bloating the SQLite store
    @Attribute(.externalStorage) var photoData: Data?

    var trip: Trip?

    init(
        amount: Double,
        note: String = "",
        category: ItemCategory = .restaurants,
        date: Date = Date(),
        paidByName: String = "",
        photoData: Data? = nil,
        trip: Trip? = nil
    ) {
        self.id          = UUID()
        self.amount      = amount
        self.note        = note
        self.categoryRaw = category.rawValue
        self.date        = date
        self.paidByName  = paidByName
        self.photoData   = photoData
        self.trip        = trip
    }

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .restaurants }
        set { categoryRaw = newValue.rawValue }
    }

    func formattedAmount(symbol: String = "$") -> String {
        amount.asCurrencyPrecise(symbol)
    }
}
