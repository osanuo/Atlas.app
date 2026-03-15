//
//  PDFExportService.swift
//  Atlas
//
//  Generates a printable PDF itinerary for a trip using UIGraphicsPDFRenderer.
//

import UIKit

// MARK: - PDF Export Service

actor PDFExportService {

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

        let data = renderer.pdfData { ctx in
            // Page 1: Cover
            ctx.beginPage()
            drawCover(trip: trip, ctx: ctx)

            // Page 2+: Items by category
            ctx.beginPage()
            drawItemsSection(trip: trip, currencySymbol: currencySymbol, ctx: ctx)
        }

        try? data.write(to: url)
        return url
    }

    // MARK: - Cover Page

    private func drawCover(trip: Trip, ctx: UIGraphicsPDFRendererContext) {
        let context = ctx.cgContext

        // Background (teal header block)
        context.setFillColor(UIColor(red: 0.25, green: 0.75, blue: 0.72, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 240))

        // Flag + destination
        let flagText = trip.destinationFlag as NSString
        flagText.draw(
            at: CGPoint(x: margin, y: 60),
            withAttributes: [.font: UIFont.systemFont(ofSize: 52)]
        )

        let destText = trip.destination.uppercased() as NSString
        destText.draw(
            at: CGPoint(x: margin, y: 124),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )

        // Date range
        let dateText = trip.dateRangeString as NSString
        dateText.draw(
            at: CGPoint(x: margin, y: 164),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.75)
            ]
        )

        // Below header: trip meta
        var y: CGFloat = 272

        drawLabel("TRIP DETAILS", y: y, ctx: ctx)
        y += 22

        let details: [(String, String)] = [
            ("Duration",    "\(trip.durationDays) day\(trip.durationDays == 1 ? "" : "s")"),
            ("Travelers",   "\(trip.travelerCount)"),
            ("Status",      trip.status.rawValue.capitalized),
            ("Budget",      trip.budget.map { "\($0.asCurrency(currencySymbol))" } ?? "Not set"),
            ("Items",       "\(trip.items.count)"),
            ("Crew",        trip.crew.isEmpty ? "Solo" : trip.crew.map(\.name).joined(separator: ", ")),
        ]

        for (label, value) in details {
            drawKeyValue(key: label, value: value, y: y, ctx: ctx)
            y += 24
        }

        // Atlas watermark at bottom
        let watermark = "Generated with Atlas" as NSString
        watermark.draw(
            at: CGPoint(x: margin, y: pageHeight - 52),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black.withAlphaComponent(0.2)
            ]
        )
    }

    // MARK: - Items Section

    private func drawItemsSection(trip: Trip, currencySymbol: String, ctx: UIGraphicsPDFRendererContext) {
        var y: CGFloat = margin

        // Budget summary
        if let budget = trip.budget {
            drawSectionHeader("BUDGET", y: y, ctx: ctx)
            y += 26

            let totalSpent = trip.expenses.reduce(0.0) { $0 + $1.amount }
            drawKeyValue(key: "Budget", value: budget.asCurrency(currencySymbol), y: y, ctx: ctx)
            y += 22
            drawKeyValue(key: "Spent",  value: totalSpent.asCurrency(currencySymbol), y: y, ctx: ctx)
            y += 22
            drawKeyValue(key: "Remaining", value: (budget - totalSpent).asCurrency(currencySymbol), y: y, ctx: ctx)
            y += 36
        }

        // Items by day (if any assigned)
        let assignedItems = trip.items.filter { $0.dayAssigned != nil }.sorted { ($0.dayAssigned ?? 0) < ($1.dayAssigned ?? 0) }
        let unassigned    = trip.items.filter { $0.dayAssigned == nil }

        if !assignedItems.isEmpty {
            y = checkPageBreak(y: y, ctx: ctx)
            drawSectionHeader("ITINERARY", y: y, ctx: ctx)
            y += 26

            let days = Dictionary(grouping: assignedItems) { $0.dayAssigned! }
            for day in days.keys.sorted() {
                y = checkPageBreak(y: y, ctx: ctx)
                drawSubHeader("Day \(day)", y: y, ctx: ctx)
                y += 22

                for item in (days[day] ?? []).sorted(by: { ($0.timeAssigned ?? .distantFuture) < ($1.timeAssigned ?? .distantFuture) }) {
                    y = checkPageBreak(y: y, ctx: ctx)
                    y = drawItem(item, y: y, currencySymbol: currencySymbol, ctx: ctx)
                }
                y += 8
            }
        }

        // Unassigned items by category
        for category in ItemCategory.allCases {
            let items = unassigned.filter { $0.category == category }
            guard !items.isEmpty else { continue }

            y = checkPageBreak(y: y, ctx: ctx)
            drawSectionHeader(category.label.uppercased(), y: y, ctx: ctx)
            y += 26

            for item in items {
                y = checkPageBreak(y: y, ctx: ctx)
                y = drawItem(item, y: y, currencySymbol: currencySymbol, ctx: ctx)
            }
            y += 8
        }
    }

    // MARK: - Drawing Helpers

    private func drawSectionHeader(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let context = ctx.cgContext
        context.setFillColor(UIColor.black.withAlphaComponent(0.06).cgColor)
        context.fill(CGRect(x: margin - 6, y: y - 2, width: contentWidth + 12, height: 22))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.5),
            .kern: 1.5
        ]
        (text as NSString).draw(at: CGPoint(x: margin, y: y + 2), withAttributes: attrs)
    }

    private func drawSubHeader(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        (text as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
    }

    private func drawLabel(_ text: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.4),
            .kern: 1.5
        ]
        (text as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
    }

    private func drawKeyValue(key: String, value: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.black.withAlphaComponent(0.4)
        ]
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        (key as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: keyAttrs)
        (value as NSString).draw(at: CGPoint(x: margin + 130, y: y), withAttributes: valAttrs)
    }

    @discardableResult
    private func drawItem(_ item: TripItem, y: CGFloat, currencySymbol: String, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var curY = y

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.black.withAlphaComponent(0.45)
        ]

        // Bullet + title
        ("• " + item.title as NSString).draw(at: CGPoint(x: margin + 8, y: curY), withAttributes: titleAttrs)
        curY += 18

        // Notes
        if !item.notes.isEmpty {
            let note = item.notes as NSString
            note.draw(at: CGPoint(x: margin + 20, y: curY), withAttributes: subAttrs)
            curY += 16
        }

        // Price
        if let price = item.price, price > 0 {
            ("\(price.asCurrency(currencySymbol))" as NSString).draw(at: CGPoint(x: margin + 20, y: curY), withAttributes: subAttrs)
            curY += 16
        }

        return curY + 4
    }

    // Returns updated y, adding a new page if content would overflow
    private func checkPageBreak(y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        if y > pageHeight - margin - 60 {
            ctx.beginPage()
            return margin
        }
        return y
    }
}

// MARK: - Double extension (needed in actor context)

private extension Double {
    func asCurrency(_ symbol: String) -> String {
        String(format: "\(symbol)%.2f", self)
    }
}
