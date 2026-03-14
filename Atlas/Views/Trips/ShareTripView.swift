//
//  ShareTripView.swift
//  Atlas
//
//  Invite UI: share link, QR code, collaborator list, stop sharing.
//

import SwiftUI
import CloudKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftData

struct ShareTripView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var shareURL: URL? = nil
    @State private var isCreatingShare = false
    @State private var showShareSheet  = false
    @State private var participants: [CKShare.Participant] = []
    @State private var errorMessage: String? = nil
    @State private var showStopSharingConfirm = false
    @State private var qrImage: UIImage? = nil

    private let sharingManager = CloudKitSharingManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
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
                    Text(trip.isShared ? "Manage Sharing" : "Share Trip")
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

                    // MARK: Trip info card
                    tripInfoCard

                    // MARK: Invite section
                    inviteSection

                    // MARK: Collaborators (only when already shared)
                    if trip.isShared && !participants.isEmpty {
                        collaboratorsSection
                    }

                    // MARK: Sync status
                    if trip.isShared {
                        syncStatusRow
                    }

                    // MARK: Stop Sharing (owner only)
                    if trip.isShared {
                        stopSharingButton
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.atlasBeige.ignoresSafeArea())
        .task {
            await loadInitialState()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .confirmationDialog(
            "Stop Sharing?",
            isPresented: $showStopSharingConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop Sharing", role: .destructive) { Task { await stopSharing() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Collaborators will lose access to this trip. This cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareLinkSheet(url: url, tripName: trip.name)
            }
        }
    }

    // MARK: - Trip Info Card

    private var tripInfoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(trip.cardColor)
                    .frame(width: 52, height: 52)
                Text(trip.destinationFlag)
                    .font(.system(size: 26))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.atlasBlack)
                Text(trip.dateRangeString)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.atlasBlack.opacity(0.5))
            }
            Spacer()
            if trip.isShared {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.statusGreen)
                        .frame(width: 7, height: 7)
                    Text("Live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.statusGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.statusGreen.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Invite Section

    @ViewBuilder
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(trip.isShared ? "Invite More People" : "Start Collaborating")
                .atlasLabel()
                .padding(.leading, 4)

            if !trip.isShared {
                // Explanation card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.wave.2")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.atlasTeal)
                        Text("Real-time collaboration")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.atlasBlack)
                    }
                    Text("Friends you invite can add places, activities, and restaurants to the trip. Changes sync automatically via iCloud.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.atlasBlack.opacity(0.55))
                        .lineSpacing(3)
                }
                .padding(16)
                .background(Color.atlasTeal.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.atlasTeal.opacity(0.2), lineWidth: 1)
                )
            }

            // Share link button (generate or copy)
            if let url = shareURL {
                // Already have a URL — show copy + share buttons
                VStack(spacing: 10) {
                    // URL display
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.atlasTeal)
                        Text(url.absoluteString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.atlasBlack.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            UIPasteboard.general.url = url
                            Haptics.success()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.atlasTeal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.atlasBlack.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Share via system sheet
                    Button {
                        showShareSheet = true
                        Haptics.medium()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text("INVITE VIA IMESSAGE / AIRDROP")
                                .font(.system(size: 12, weight: .bold))
                                .kerning(0.5)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.atlasTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // QR Code
                    if let qrImage {
                        VStack(spacing: 8) {
                            Text("QR Code")
                                .atlasLabel()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 4)
                            Image(uiImage: qrImage)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 160, height: 160)
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                // Generate share link button
                Button {
                    Task { await generateShareLink() }
                } label: {
                    HStack(spacing: 10) {
                        if isCreatingShare {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(isCreatingShare ? "Creating Link…" : "GENERATE INVITE LINK")
                            .font(.system(size: 13, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(isCreatingShare ? .white.opacity(0.7) : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isCreatingShare ? Color.atlasBlack.opacity(0.5) : Color.atlasBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isCreatingShare)
            }
        }
    }

    // MARK: - Collaborators Section

    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collaborators (\(participants.count))")
                .atlasLabel()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(participants.enumerated()), id: \.offset) { index, participant in
                    ParticipantRow(participant: participant)

                    if index < participants.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Sync Status Row

    private var syncStatusRow: some View {
        HStack(spacing: 10) {
            let state = sharingManager.syncState
            Image(systemName: syncIcon(state))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(syncColor(state))
            Text(syncLabel(state))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.atlasBlack.opacity(0.55))
            Spacer()
            if case .syncing = state {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color.atlasTeal)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    // MARK: - Stop Sharing Button

    private var stopSharingButton: some View {
        Button {
            showStopSharingConfirm = true
            Haptics.medium()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Stop Sharing")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadInitialState() async {
        // Load existing share URL if trip is already shared
        if trip.isShared, let urlString = trip.shareURL, let url = URL(string: urlString) {
            shareURL = url
            qrImage  = generateQRCode(from: urlString)
        }
        // Fetch participants
        if trip.isShared {
            participants = (try? await sharingManager.fetchParticipants(for: trip)) ?? []
        }
    }

    private func generateShareLink() async {
        isCreatingShare = true
        do {
            let url = try await sharingManager.createShare(for: trip)
            await MainActor.run {
                shareURL = url
                qrImage  = generateQRCode(from: url.absoluteString)
                isCreatingShare = false
                Haptics.success()
            }
            participants = (try? await sharingManager.fetchParticipants(for: trip)) ?? []
        } catch {
            await MainActor.run {
                isCreatingShare = false
                errorMessage = error.localizedDescription
                Haptics.medium()
            }
        }
    }

    private func stopSharing() async {
        do {
            try await sharingManager.stopSharing(trip)
            await MainActor.run {
                shareURL     = nil
                participants = []
                qrImage      = nil
                Haptics.success()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - QR Code Generator

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        // Scale up for crispness
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Sync State Helpers

    private func syncIcon(_ state: CloudKitSyncState) -> String {
        switch state {
        case .idle:        return "cloud"
        case .syncing:     return "arrow.triangle.2.circlepath.icloud"
        case .upToDate:    return "checkmark.icloud"
        case .error:       return "exclamationmark.icloud"
        }
    }

    private func syncColor(_ state: CloudKitSyncState) -> Color {
        switch state {
        case .idle:        return Color.atlasBlack.opacity(0.3)
        case .syncing:     return Color.atlasTeal
        case .upToDate:    return Color.statusGreen
        case .error:       return Color.red
        }
    }

    private func syncLabel(_ state: CloudKitSyncState) -> String {
        switch state {
        case .idle:           return "Not syncing"
        case .syncing:        return "Syncing changes…"
        case .upToDate:       return "Up to date"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let participant: CKShare.Participant

    private var displayName: String {
        participant.userIdentity.nameComponents
            .map { PersonNameComponentsFormatter().string(from: $0) }
            ?? "Unknown"
    }

    private var isOwner: Bool {
        participant.role == .owner
    }

    private var permissionLabel: String {
        switch participant.permission {
        case .readWrite: return "Can Edit"
        case .readOnly:  return "Viewer"
        default:         return ""
        }
    }

    private var initials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased().isEmpty ? "?" : (first + last).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isOwner ? Color.atlasTeal : Color.atlasBlack.opacity(0.1))
                    .frame(width: 38, height: 38)
                Text(initials)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isOwner ? .white : Color.atlasBlack)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.atlasBlack)
                    if isOwner {
                        Text("Owner")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.atlasTeal)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.atlasTeal.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                if !permissionLabel.isEmpty && !isOwner {
                    Text(permissionLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.atlasBlack.opacity(0.45))
                }
            }

            Spacer()

            // Status dot
            Circle()
                .fill(participant.acceptanceStatus == .accepted ? Color.statusGreen : Color.statusYellow)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Share Link Sheet (wraps UIActivityViewController)

private struct ShareLinkSheet: UIViewControllerRepresentable {
    let url: URL
    let tripName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = "Join me planning our trip to \(tripName) on Atlas!"
        return UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareTripView(trip: Trip(
        name: "Tokyo Adventure",
        destination: "TOKYO",
        destinationFlag: "🇯🇵",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 10),
        cardColorHex: "FCDA85"
    ))
    .modelContainer(for: [Trip.self, TripItem.self, CrewMember.self], inMemory: true)
}
