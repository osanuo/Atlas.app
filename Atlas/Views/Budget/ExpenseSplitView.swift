//
//  ExpenseSplitView.swift
//  Atlas
//
//  Per-person expense split. Pro feature.
//

import SwiftUI

// MARK: - Expense Split View

struct ExpenseSplitView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfile.self) private var userProfile

    private var totalSpent: Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }

    private var crewNames: [String] {
        trip.crew.map(\.name)
    }

    // Split model: who paid how much
    private struct MemberSplit: Identifiable {
        let id: String   // crew member name
        let name: String
        let totalPaid: Double
        let fairShare: Double
        var balance: Double { totalPaid - fairShare }
    }

    private var splits: [MemberSplit] {
        let memberCount = max(crewNames.count, 1)
        let fairShare = totalSpent / Double(memberCount)

        // Calculate how much each named person paid
        var paid: [String: Double] = [:]
        for name in crewNames { paid[name] = 0 }

        for expense in trip.expenses {
            if !expense.paidByName.isEmpty, crewNames.contains(expense.paidByName) {
                paid[expense.paidByName, default: 0] += expense.amount
            }
            // Expenses without paidByName are ignored in the "who paid" calculation
        }

        return crewNames.map { name in
            MemberSplit(
                id: name,
                name: name,
                totalPaid: paid[name] ?? 0,
                fairShare: fairShare
            )
        }
    }

    private var unassignedAmount: Double {
        let assignedTotal = trip.expenses.filter { crewNames.contains($0.paidByName) }.reduce(0) { $0 + $1.amount }
        return totalSpent - assignedTotal
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            ZStack {
                Color.atlasBlack
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Split Expenses")
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

                    // Summary tile
                    summaryTile

                    // Per-person breakdown
                    if !splits.isEmpty {
                        perPersonSection
                    }

                    // How to settle
                    settleSection

                    // Note about unassigned
                    if unassignedAmount > 0.01 {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                            Text("\(unassignedAmount.asCurrency(userProfile.currencySymbol)) in expenses has no assigned payer. Edit expenses to assign payers for an accurate split.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.atlasBlack.opacity(0.4))
                        }
                        .padding(.horizontal, 4)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
    }

    // MARK: - Summary Tile

    private var summaryTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.atlasBlack)

            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL SPENT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        Text(totalSpent.asCurrency(userProfile.currencySymbol))
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("PER PERSON")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        let perPerson = trip.crew.isEmpty ? totalSpent : totalSpent / Double(trip.crew.count)
                        Text(perPerson.asCurrency(userProfile.currencySymbol))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.atlasTeal)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                HStack {
                    Text("\(trip.crew.count) crew member\(trip.crew.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("\(trip.expenses.count) expense\(trip.expenses.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Per-Person Section

    private var perPersonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREAKDOWN")
                .atlasLabel()

            VStack(spacing: 0) {
                ForEach(splits) { split in
                    splitRow(split: split)
                    if split.id != splits.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func splitRow(split: MemberSplit) -> some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(Color.atlasTeal.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(split.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.atlasTeal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(split.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasBlack)
                Text("Paid \(split.totalPaid.asCurrency(userProfile.currencySymbol)) · Fair share \(split.fairShare.asCurrency(userProfile.currencySymbol))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.atlasBlack.opacity(0.4))
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                let balance = split.balance
                Text(balance >= 0
                     ? "+\(balance.asCurrency(userProfile.currencySymbol))"
                     : balance.asCurrency(userProfile.currencySymbol))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(balance >= 0.01 ? Color.atlasTeal : balance <= -0.01 ? Color.red.opacity(0.8) : Color.atlasBlack.opacity(0.3))
                Text(balance >= 0.01 ? "gets back" : balance <= -0.01 ? "owes" : "settled")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.atlasBlack.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Settle Section

    private var settleSection: some View {
        let settlements = computeSettlements()
        guard !settlements.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("HOW TO SETTLE")
                    .atlasLabel()

                VStack(spacing: 0) {
                    ForEach(Array(settlements.enumerated()), id: \.offset) { idx, settlement in
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.atlasTeal)
                                .frame(width: 20)

                            Text("\(settlement.from)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.atlasBlack)
                            Text("pays")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.atlasBlack.opacity(0.5))
                            Text(settlement.amount.asCurrency(userProfile.currencySymbol))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.atlasBlack)
                            Text("to")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.atlasBlack.opacity(0.5))
                            Text("\(settlement.to)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.atlasBlack)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if idx < settlements.count - 1 {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        )
    }

    // MARK: - Settlement Algorithm (greedy)

    private struct Settlement {
        let from: String
        let to: String
        let amount: Double
    }

    private func computeSettlements() -> [Settlement] {
        var balances = splits.map { ($0.name, $0.balance) }

        var result: [Settlement] = []
        var debtors  = balances.filter { $0.1 < -0.005 }.sorted { $0.1 < $1.1 }
        var creditors = balances.filter { $0.1 > 0.005 }.sorted { $0.1 > $1.1 }

        var di = 0, ci = 0
        while di < debtors.count && ci < creditors.count {
            let debtorName   = debtors[di].0
            let creditorName = creditors[ci].0
            let transfer = min(-debtors[di].1, creditors[ci].1)
            result.append(Settlement(from: debtorName, to: creditorName, amount: transfer))
            debtors[di].1  += transfer
            creditors[ci].1 -= transfer
            if abs(debtors[di].1)  < 0.005 { di += 1 }
            if abs(creditors[ci].1) < 0.005 { ci += 1 }
        }

        return result
    }
}
