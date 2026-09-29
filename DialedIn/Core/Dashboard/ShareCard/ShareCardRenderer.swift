//
//  ShareCardRenderer.swift
//  DialedIn
//

import SwiftUI
import UIKit

/// Turns a `WorkoutShareCardView` into a `UIImage` for the share sheet.
@MainActor
enum ShareCardRenderer {

    static let scale: CGFloat = 3

    static func render(_ content: ShareCardContent, avatar: UIImage?, format: WorkoutShareCardView.Format) -> UIImage? {
        let renderer = ImageRenderer(content: WorkoutShareCardView(content: content, avatar: avatar, format: format))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }

    /// Loads the avatar first, since the renderer will not wait for it, then renders. An avatar
    /// that cannot be fetched in a few seconds is left out; the card falls back to an initial.
    static func renderCard(_ content: ShareCardContent, format: WorkoutShareCardView.Format) async -> UIImage? {
        render(content, avatar: await loadAvatar(content.avatarURL), format: format)
    }

    static func loadAvatar(_ urlString: String?) async -> UIImage? {
        guard let urlString else { return nil }
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            // Mock and placeholder avatars are asset names.
            return UIImage(named: urlString)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return UIImage(data: data)
    }
}

/// `UIActivityViewController`, for sharing a rendered image. `ShareLink` needs a `Transferable`
/// ready before the button is tapped, and the card is rendered only once it is.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

/// A screen that can hand a rendered card to the system share sheet.
@MainActor
protocol ShareSheetRouter: GlobalRouter {
    func showShareSheet(items: [Any])
}

extension ShareSheetRouter {
    func showShareSheet(items: [Any]) {
        router.showScreen(.sheet) { _ in
            ShareSheet(items: items)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }
}
