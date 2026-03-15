//
//  ShareExtensionViewController.swift
//  AtlasShareExtension
//
//  iOS Share Extension: saves web pages from Safari to Atlas Wishlist or Trip Collections.
//
//  SETUP REQUIRED in Xcode:
//  1. Add an "App Extension" target: Share Extension → name "AtlasShareExtension"
//  2. Add App Group "group.com.osanuo.Atlas" to both Atlas and AtlasShareExtension targets
//  3. Replace the default extensionContext host view controller with this file
//  4. In Info.plist of the extension:
//     NSExtensionPrincipalClass → AtlasShareExtension.ShareExtensionViewController
//     NSExtensionActivationRule → { NSExtensionActivationSupportsWebPageWithMaxCount = 1 }
//

import UIKit
import SwiftUI
import Social
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - Pending Share Item (stored in shared UserDefaults)

struct PendingShareItem: Codable {
    let id: String
    let title: String
    let urlString: String
    let destination: String        // "wishlist" or "collection"
    let tripID: String?            // UUID string, if destination == "collection"
    let categoryRaw: String?       // ItemCategory.rawValue
    let dateAdded: Date
}

// MARK: - Share Extension Root

final class ShareExtensionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Parse the incoming URL + title from the share sheet
        extractItem { [weak self] title, urlString in
            DispatchQueue.main.async {
                guard let self else { return }

                let hosted = UIHostingController(
                    rootView: ShareExtensionView(
                        initialTitle: title,
                        urlString: urlString
                    ) { item in
                        self.save(item: item)
                        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    } onCancel: {
                        self.extensionContext?.cancelRequest(withError: NSError(domain: "AtlasCancel", code: 0))
                    }
                )
                hosted.view.frame = self.view.bounds
                hosted.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.addChild(hosted)
                self.view.addSubview(hosted.view)
                hosted.didMove(toParent: self)
            }
        }
    }

    // MARK: - Extract URL/Title

    private func extractItem(completion: @escaping (String, String) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion("", "")
            return
        }

        for item in items {
            for attachment in (item.attachments ?? []) {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        let urlString = (data as? URL)?.absoluteString ?? ""
                        let title = item.attributedContentText?.string ?? item.attributedTitle?.string ?? ""
                        completion(title, urlString)
                    }
                    return
                }
            }
        }
        completion("", "")
    }

    // MARK: - Save to Shared UserDefaults Queue

    private func save(item: PendingShareItem) {
        let shared = UserDefaults(suiteName: "group.com.osanuo.Atlas")

        // Read existing queue
        var queue: [PendingShareItem] = []
        if let data = shared?.data(forKey: "atlas_pendingShareItems"),
           let decoded = try? JSONDecoder().decode([PendingShareItem].self, from: data) {
            queue = decoded
        }

        queue.append(item)

        if let encoded = try? JSONEncoder().encode(queue) {
            shared?.set(encoded, forKey: "atlas_pendingShareItems")
        }
    }
}

// MARK: - Share Extension SwiftUI View

struct ShareExtensionView: View {
    let initialTitle: String
    let urlString: String
    let onSave: (PendingShareItem) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var destination: ShareDestination = .wishlist
    @State private var isPro: Bool

    enum ShareDestination: String, CaseIterable {
        case wishlist   = "wishlist"
        case collection = "collection"
    }

    init(initialTitle: String, urlString: String, onSave: @escaping (PendingShareItem) -> Void, onCancel: @escaping () -> Void) {
        self.initialTitle = initialTitle
        self.urlString    = urlString
        self.onSave       = onSave
        self.onCancel     = onCancel
        _title  = State(initialValue: initialTitle)
        _isPro  = State(initialValue: UserDefaults(suiteName: "group.com.osanuo.Atlas")?.bool(forKey: "atlas_isPro") ?? false)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    Color(red: 0.25, green: 0.75, blue: 0.72)
                    Text("Save to Atlas")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(height: 56)

                Form {
                    // Title field
                    Section("Title") {
                        TextField("Page title", text: $title)
                    }

                    // URL preview
                    if !urlString.isEmpty {
                        Section("URL") {
                            Text(urlString)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    // Destination
                    Section("Save to") {
                        Picker("Destination", selection: $destination) {
                            Text("Wishlist").tag(ShareDestination.wishlist)
                            if isPro {
                                Text("Trip Collection (Pro)").tag(ShareDestination.collection)
                            } else {
                                Text("Trip Collection — Pro Only").tag(ShareDestination.wishlist)
                                    .disabled(true)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    if !isPro && destination == .collection {
                        Section {
                            Text("Trip Collection is a Pro feature. Upgrade to Atlas Pro to save items directly to trips.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = PendingShareItem(
                            id: UUID().uuidString,
                            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? urlString : title,
                            urlString: urlString,
                            destination: destination.rawValue,
                            tripID: nil,
                            categoryRaw: nil,
                            dateAdded: Date()
                        )
                        onSave(item)
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && urlString.isEmpty)
                }
            }
        }
    }
}
