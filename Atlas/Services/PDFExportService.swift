//
//  PDFExportService.swift
//  Atlas
//
//  Generates a printable PDF itinerary for a trip using UIGraphicsPDFRenderer.
//

import UIKit

// MARK: - PDF Export Service

struct PDFExportService {

    static let shared = PDFExportService()
    private init() {}

    // MARK: - Page Metrics

    private let pageWidth:  CGFloat = 595  // A4 in points (72 dpi)
    private let pageHeight: CGFloat = 842
    private let margin:     CGFloat = 48

    private var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Generate

    func generateItinerary(for trip: Trip, currencySymbol: String) -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let filename = "\(trip.destination.capitalized)_Atlas_Itinerary.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // Pre-compute all strings that require MainActor context before entering the renderer closure
        let coverData  = buildCoverData(trip: trip, currencySymbol: currencySymbol)
        let sectionData = buildSectionData(trip: trip, currencySymbol: currencySymbol)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            drawCover(data: coverData, ctx: ctx)
            ctx.beginPage()
            drawItemsSection(data: sectionData, ctx: ctx)
        }

        try? data.write(to: url)
        return url
    }

    // MARK: - Pre-compute Data Structures

    private struct CoverData {
        let flag: String
        let destination: String
        let dateRange: String
        let details: [(key: String, value: String)]
    }

    private struct ItemRowData {
        let title: String
        let notes: String
        let priceStr: String   // empty if no price
    }

    private struct DaySection {
        let header: String   // formatted date, e.g. "Mon, Mar 15"
        let date: Date       // used for sorting
        let items: [ItemRowData]
    }

    private struct CategorySection {
        let header: String
        let items: [ItemRowData]
    }

    private struct SectionData {
        let budgetRows: [(key: String, value: String)]   // empty if no budget
        let daySections: [DaySection]
        let categorySections: [CategorySection]
    }

    private func buildCoverData(trip: Trip, currencySymbol: String) -> CoverData {
        let budgetVal: String
        if let b = trip.budget {
            budgetVal = fmt(b, symbol: currencySymbol)
        } else {
            budgetVal = "Not set"
        }
        let crewArray: [CrewMember] = Array(trip.crew)
        let crewVal = crewArray.isEmpty ? "Solo" : crewArray.map(\.name).joined(separator: ", ")
        let daysVal = "\(trip.durationDays) day\(trip.durationDays == 1 ? "" : "s")"

        let details: [(key: String, value: String)] = [
            (key: "Duration",  value: daysVal),
            (key: "Travelers", value: "\(trip.travelerCount)"),
            (key: "Status",    value: trip.status.rawValue.capitalized),
            (key: "Budget",    value: budgetVal),
            (key: "Items",     value: "\(trip.items.count)"),
            (key: "Crew",      value: crewVal),
        ]
        return CoverData(
            flag: trip.destinationFlag,
            destination: trip.destination.uppercased(),
            dateRange: trip.dateRangeString,
            details: details
        )
    }

    private func buildSectionData(trip: Trip, currencySymbol: String) -> SectionData {
        // Budget rows
        var budgetRows: [(key: String, value: String)] = []
        if let budget = trip.budget {
            let expenseArray: [Expense] = Array(trip.expenses)
            let totalSpent: Double = expenseArray.reduce(0.0) { (acc: Double, e: Expense) -> Double in acc + e.amount }
            budgetRows = [
                (key: "Budget",    value: fmt(budget, symbol: currencySymbol)),
                (key: "Spent",     value: fmt(totalSpent, symbol: currencySymbol)),
                (key: "Remaining", value: fmt(budget - totalSpent, symbol: currencySymbol)),
            ]
        }

        // Day sections — materialise SwiftData proxy into a plain Array first
        let cal = Calendar.current
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE, MMM d"

        let allItems: [TripItem] = Array(trip.items)
        let withDay: [TripItem] = allItems.filter { $0.dayAssigned != nil }

        // Group by calendar day (startOfDay normalises time-of-day differences)
        var grouped: [Date: [TripItem]] = [:]
        for item in withDay {
            let key = cal.startOfDay(for: item.dayAssigned!)
            grouped[key, default: []].append(item)
        }

        let sortedDayKeys: [Date] = grouped.keys.sorted()
        let daySections: [DaySection] = sortedDayKeys.map { (day: Date) -> DaySection in
            let dayItems: [TripItem] = grouped[day] ?? []
            let sortedItems: [TripItem] = dayItems.sorted { (a: TripItem, b: TripItem) -> Bool in
                (a.timeAssigned ?? Date.distantFuture) < (b.timeAssigned ?? Date.distantFuture)
            }
            let rows: [ItemRowData] = sortedItems.map { (item: TripItem) -> ItemRowData in
                itemRow(item, symbol: currencySymbol)
            }
            return DaySection(header: dayFmt.string(from: day), date: day, items: rows)
        }

        // Category sections
        let unassigned: [TripItem] = allItems.filter { $0.dayAssigned == nil }
        let categorySections: [CategorySection] = ItemCategory.allCases.compactMap { (cat: ItemCategory) -> CategorySection? in
            let items: [TripItem] = unassigned.filter { $0.category == cat }
            guard !items.isEmpty else { return nil }
            let rows: [ItemRowData] = items.map { (item: TripItem) -> ItemRowData in itemRow(item, symbol: currencySymbol) }
            return CategorySection(header: categoryLabel(cat).uppercased(), items: rows)
        }

        return SectionData(budgetRows: budgetRows, daySections: daySections, categorySections: categorySections)
    }

    private func itemRow(_ item: TripItem, symbol: String) -> ItemRowData {
        let priceStr: String
        if let p = item.price, p > 0 { priceStr = fmt(p, symbol: symbol) } else { priceStr = "" }
        return ItemRowData(title: item.title, notes: item.notes, priceStr: priceStr)
    }

    /// Local currency formatter — avoids dependency on @MainActor-isolated extension
    private func fmt(_ amount: Double, symbol: String) -> String {
        String(format: "\(symbol)%.0f", amount)
    }

    /// Local category label — avoids dependency on @MainActor-isolated .label property
    private func categoryLabel(_ cat: ItemCategory) -> String {
        switch cat {
        case .restaurants:    return "Restaurants"
        case .places:         return "Places"
        case .paidActivities: return "Activities"
        case .freeActivities: return "Free"
        case .accommodation:  return "Stay"
        case .transportation: return "Transport"
        }
    }

    // MARK: - Cover Page

    private func drawCover(data: CoverData, ctx: UIGraphicsPDFRendererContext) {
        let context = ctx.cgContext

        context.setFillColor(UIColor(red: 0.25, green: 0.75, blue: 0.72, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 240))

        (data.flag as NSString).draw(
            at: CGPoint(x: margin, y: 60),
            withAttributes: [.font: UIFont.systemFont(ofSize: 52)]
        )
        (data.destination as NSString).draw(
            at: CGPoint(x: margin, y: 124),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )
        (data.dateRange as NSString).draw(
            at: CGPoint(x: margin, y: 164),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.75)
            ]
        )

        var y: CGFloat = 272
        drawLabel("TRIP DETAILS", y: y, ctx: ctx)
        y += 22

        for row in data.details {
            drawKeyValue(key: row.key, value: row.value, y: y, ctx: ctx)
            y += 24
        }

        ("Generated with Atlas" as NSString).draw(
            at: CGPoint(x: margin, y: pageHeight - 52),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black.withAlphaComponent(0.2)
            ]
        )
    }

    // MARK: - Items Section

    private func drawItemsSection(data: SectionData, ctx: UIGraphicsPDFRendererContext) {
        var y: CGFloat = margin

        if !data.budgetRows.isEmpty {
            drawSectionHeader("BUDGET", y: y, ctx: ctx)
            y += 26
            for row in data.budgetRows {
                drawKeyValue(key: row.key, value: row.value, y: y, ctx: ctx)
                y += 22
            }
            y += 14
        }

        if !data.daySections.isEmpty {
            y = checkPageBreak(y: y, ctx: ctx)
            drawSectionHeader("ITINERARY", y: y, ctx: ctx)
            y += 26
            for section in data.daySections {
                y = checkPageBreak(y: y, ctx: ctx)
                drawSubHeader(section.header, y: y, ctx: ctx)
                y += 22
                for item in section.items {
                    y = checkPageBreak(y: y, ctx: ctx)
                    y = drawItemRow(item, y: y, ctx: ctx)
                }
                y += 8
            }
        }

        for section in data.categorySections {
            y = checkPageBreak(y: y, ctx: ctx)
            drawSectionHeader(section.header, y: y, ctx: ctx)
            y += 26
            for item in section.items {
                y = checkPageBreak(y: y, ctx: ctx)
                y = drawItemRow(item, y: y, ctx: ctx)
            }
            y += 8
        }
    }

    // MARK: - Drawing Helpers

    private func drawSectionHeader(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let context = ctx.cgContext
        context.setFillColor(UIColor.black.withAlphaComponent(0.06).cgColor)
        context.fill(CGRect(x: margin - 6, y: y - 2, width: contentWidth + 12, height: 22))
        (text as NSString).draw(
            at: CGPoint(x: margin, y: y + 2),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.black.withAlphaComponent(0.5),
                .kern: 1.5 as CGFloat
            ]
        )
    }

    private func drawSubHeader(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        (text as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.black
            ]
        )
    }

    private func drawLabel(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        (text as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor.black.withAlphaComponent(0.4),
                .kern: 1.5 as CGFloat
            ]
        )
    }

    private func drawKeyValue(key: String, value: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        (key as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.black.withAlphaComponent(0.4)
            ]
        )
        (value as NSString).draw(
            at: CGPoint(x: margin + 130, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
        )
    }

    @discardableResult
    private func drawItemRow(_ item: ItemRowData, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var curY = y
        let titleStr = "• " + item.title
        (titleStr as NSString).draw(
            at: CGPoint(x: margin + 8, y: curY),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
        )
        curY += 18

        if !item.notes.isEmpty {
            (item.notes as NSString).draw(
                at: CGPoint(x: margin + 20, y: curY),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.45)
                ]
            )
            curY += 16
        }

        if !item.priceStr.isEmpty {
            (item.priceStr as NSString).draw(
                at: CGPoint(x: margin + 20, y: curY),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.45)
                ]
            )
            curY += 16
        }

        return curY + 4
    }

    private func checkPageBreak(y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        if y > pageHeight - margin - 60 {
            ctx.beginPage()
            return margin
        }
        return y
    }
}

