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

    var trip: Trip?

    init(
        amount: Double,
        note: String = "",
        category: ItemCategory = .restaurants,
        date: Date = Date(),
        trip: Trip? = nil
    ) {
        self.id          = UUID()
        self.amount      = amount
        self.note        = note
        self.categoryRaw = category.rawValue
        self.date        = date
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
