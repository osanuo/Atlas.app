//
//  CrewMemberCard.swift
//  Atlas
//

import SwiftUI
import SwiftData

struct CrewMemberCard: View {
    let member: CrewMember

    @Environment(\.modelContext) private var modelContext
    @State private var showStatusMenu = false

    var body: some View {
        HStack(spacing: 14) {
            // Avatar with status dot
            ZStack(alignment: .bottomTrailing) {
                AvatarInitialsView(
                    initials: member.initials,
                    size: 48,
                    colorSeed: member.name.hashValue
                )

                StatusDot(color: member.status.dotColor, size: 12)
                    .offset(x: 2, y: 2)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.atlasBlack)

                Text(member.subtitleText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack.opacity(0.5))
                    .textCase(.uppercase)
            }

            Spacer()

            // Status pill — confirmed = white (with border), pending/declined = black
            Button {
                showStatusMenu = true
                Haptics.light()
            } label: {
                PillBadge(
                    label: member.status.label,
                    style: member.status == .confirmed ? .white : .black
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(member.status.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .confirmationDialog("Update Status", isPresented: $showStatusMenu, titleVisibility: .visible) {
            ForEach(CrewStatus.allCases, id: \.rawValue) { status in
                Button(status.label) {
                    withAnimation {
                        member.status = status
                        Haptics.success()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
