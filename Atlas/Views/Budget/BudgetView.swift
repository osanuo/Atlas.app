//
//  BudgetView.swift
//  Atlas
//

import SwiftUI
import SwiftData

// MARK: - Budget View

struct BudgetView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile
    @State private var showAddExpense = false

    // MARK: Computed

    private var totalSpent: Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Double {
        (trip.budget ?? 0) - totalSpent
    }

    private var spendingRatio: CGFloat {
        guard let budget = trip.budget, budget > 0 else { return 0 }
        return min(CGFloat(totalSpent) / CGFloat(budget), 1.0)
    }

    private var isOverBudget: Bool {
        guard let budget = trip.budget else { return false }
        return totalSpent > budget
    }

    private var categoryTotals: [(ItemCategory, Double)] {
        var totals: [ItemCategory: Double] = [:]
        for expense in trip.expenses {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals.sorted { $0.value > $1.value }
    }

    private var sortedExpenses: [Expense] {
        trip.expenses.sorted { $0.date > $1.date }
    }

    private var completedCount: Int { trip.items.filter { $0.isCompleted }.count }
    private var totalItems: Int { trip.items.count }
    private var completionRatio: CGFloat {
        totalItems > 0 ? CGFloat(completedCount) / CGFloat(totalItems) : 0
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 20) {

            // Budget summary
            budgetSummaryCard

            // Trip overview (replaces Overview tab)
            tripOverviewCard

            // Category breakdown
            if !categoryTotals.isEmpty {
                categoryBreakdown
            }

            // Expense list
            if sortedExpenses.isEmpty {
                expenseEmptyState
            } else {
                expenseList
            }

            Spacer().frame(height: 80)
        }
        .overlay(alignment: .bottomTrailing) {
            addExpenseFAB
                .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(trip: trip)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Budget Summary Card

    private var budgetSummaryCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.atlasBlack)

            VStack(spacing: 16) {

                // Top row: Budget + Remaining
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRIP BUDGET")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        if let budget = trip.budget {
                            Text(budget.asCurrency(userProfile.currencySymbol))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        } else {
                            Text("No budget set")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isOverBudget ? "OVER BUDGET" : (trip.budget != nil ? "REMAINING" : "TOTAL SPENT"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isOverBudget ? Color.red.opacity(0.8) : Color.atlasTeal.opacity(0.8))
                            .kerning(1.5)
                        Text(trip.budget != nil
                             ? "\(isOverBudget ? "+" : "")\(abs(remaining).asCurrency(userProfile.currencySymbol))"
                             : totalSpent.asCurrency(userProfile.currencySymbol))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(isOverBudget ? Color.red : Color.atlasTeal)
                    }
                }

                // Progress bar (only if budget is set)
                if trip.budget != nil {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(isOverBudget ? Color.red : Color.atlasTeal)
                                    .frame(width: geo.size.width * spendingRatio, height: 6)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spendingRatio)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text("SPENT: \(totalSpent.asCurrency(userProfile.currencySymbol))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                            Text("\(Int(spendingRatio * 100))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(isOverBudget ? Color.red.opacity(0.8) : Color.atlasTeal.opacity(0.8))
                        }
                    }
                } else {
                    // No budget — show spent total inline
                    HStack {
                        Text("LOGGED EXPENSES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        Spacer()
                        Text(totalSpent.asCurrency(userProfile.currencySymbol))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }

                // Per-person row
                if trip.travelerCount > 1 && totalSpent > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    HStack {
                        Text("PER PERSON")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        Spacer()
                        Text((totalSpent / Double(trip.travelerCount)).asCurrency(userProfile.currencySymbol))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Trip Overview Card

    private var tripOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRIP OVERVIEW")
                .atlasLabel()

            VStack(spacing: 12) {

                // Completion progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Item Completion")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.atlasBlack)
                        Spacer()
                        Text("\(completedCount)/\(totalItems)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.atlasBlack.opacity(0.5))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.atlasBlack.opacity(0.08))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.atlasTeal)
                                .frame(width: geo.size.width * completionRatio, height: 6)
                                .animation(.spring(response: 0.5), value: completionRatio)
                        }
                    }
                    .frame(height: 6)
                }

                if !trip.crew.isEmpty {
                    Rectangle()
                        .fill(Color.atlasBlack.opacity(0.06))
                        .frame(height: 1)

                    // Crew summary
                    HStack(spacing: -6) {
                        ForEach(trip.crew.prefix(5)) { member in
                            ZStack {
                                Circle()
                                    .fill(Color.atlasTeal.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.atlasTeal)
                            }
                            .overlay(Circle().stroke(Color.atlasBeige, lineWidth: 2))
                        }
                        if trip.crew.count > 5 {
                            ZStack {
                                Circle()
                                    .fill(Color.atlasBlack.opacity(0.08))
                                    .frame(width: 28, height: 28)
                                Text("+\(trip.crew.count - 5)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.atlasBlack.opacity(0.5))
                            }
                            .overlay(Circle().stroke(Color.atlasBeige, lineWidth: 2))
                        }
                    }
                    HStack {
                        Text("\(trip.crew.count) crew member\(trip.crew.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.atlasBlack.opacity(0.5))
                        Spacer()
                        Text("\(trip.confirmedCrewCount) confirmed")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.atlasTeal)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY CATEGORY")
                .atlasLabel()

            VStack(spacing: 10) {
                ForEach(categoryTotals, id: \.0.rawValue) { (category, amount) in
                    categoryRow(category: category, amount: amount)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func categoryRow(category: ItemCategory, amount: Double) -> some View {
        let ratio: CGFloat = totalSpent > 0 ? CGFloat(amount / totalSpent) : 0
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.accentColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(category.accentColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.atlasBlack)
                    Spacer()
                    Text(amount.asCurrency(userProfile.currencySymbol))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.atlasBlack)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.atlasBlack.opacity(0.06))
                            .frame(height: 4)
                        Capsule()
                            .fill(category.accentColor)
                            .frame(width: geo.size.width * ratio, height: 4)
                            .animation(.spring(response: 0.4), value: ratio)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    // MARK: - Expense List

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL EXPENSES")
                .atlasLabel()

            VStack(spacing: 0) {
                ForEach(sortedExpenses) { expense in
                    ExpenseRow(expense: expense) {
                        withAnimation {
                            modelContext.delete(expense)
                            Haptics.light()
                        }
                    }
                    if expense.id != sortedExpenses.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Empty State

    private var expenseEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.atlasTeal.opacity(0.08))
                    .frame(width: 72, height: 72)
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.atlasTeal.opacity(0.5))
            }
            VStack(spacing: 4) {
                Text("No expenses yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                Text("Tap + ADD EXPENSE to start tracking")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - FAB

    private var addExpenseFAB: some View {
        Button {
            showAddExpense = true
            Haptics.medium()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("ADD EXPENSE")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.5)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color.atlasBlack)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void
    @Environment(UserProfile.self) private var userProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(expense.category.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(expense.category.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? expense.category.label : expense.note)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                    .lineLimit(1)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }

            Spacer()

            Text(expense.formattedAmount(symbol: userProfile.currencySymbol))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.atlasBlack)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Expense View

struct AddExpenseView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfile.self) private var userProfile

    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var selectedCategory: ItemCategory = .restaurants
    @State private var date: Date = Date()
    @FocusState private var amountFocused: Bool

    private var isValid: Bool {
        guard let a = Double(amount) else { return false }
        return a > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Teal header
            ZStack {
                Color.atlasTeal
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Add Expense")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Amount (dark tile)
                    VStack(spacing: 8) {
                        Text("Amount")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "222222"))
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 26)
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 1)
                                Color.clear.frame(height: 26)
                            }
                            HStack(spacing: 4) {
                                Text(userProfile.currencySymbol)
                                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white)
                                    .keyboardType(.decimalPad)
                                    .focused($amountFocused)
                                    .tint(Color.atlasTeal)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") { amountFocused = false }
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.atlasTeal)
                                        }
                                    }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(height: 70)
                    }

                    // Category picker
                    VStack(spacing: 8) {
                        Text("Category")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ItemCategory.allCases, id: \.rawValue) { category in
                                    Button {
                                        selectedCategory = category
                                        Haptics.light()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 12))
                                            Text(category.label)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .foregroundStyle(selectedCategory == category ? .white : Color.atlasBlack)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(selectedCategory == category ? category.accentColor : Color.white)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Note
                    VStack(spacing: 8) {
                        Text("Note (Optional)")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        TextField("e.g. Dinner at Sukiyabashi", text: $note)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.atlasBlack)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Date
                    VStack(spacing: 8) {
                        Text("Date")
                            .atlasLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)

                        HStack {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.atlasTeal)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }

                    // Save button
                    Button { saveExpense() } label: {
                        HStack(spacing: 10) {
                            Text("LOG EXPENSE")
                                .font(.system(size: 14, weight: .bold))
                                .kerning(1)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(isValid ? .white : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isValid ? Color.atlasBlack : Color.atlasBlack.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!isValid)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .onAppear { amountFocused = true }
    }

    private func saveExpense() {
        guard let a = Double(amount), a > 0 else { return }
        let expense = Expense(
            amount: a,
            note: note.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            date: date,
            trip: trip
        )
        modelContext.insert(expense)
        Haptics.success()
        dismiss()
    }
}
