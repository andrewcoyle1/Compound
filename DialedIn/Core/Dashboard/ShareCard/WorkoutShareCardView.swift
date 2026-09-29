//
//  WorkoutShareCardView.swift
//  DialedIn
//

import SwiftUI

/// A finished session laid out as an image for Stories or a square post. Drawn at a fixed point
/// size and rendered at 3×, so `story` comes out 1080 × 1920 and `square` 1080 × 1080.
///
/// Takes its avatar as an already loaded image: `ImageRenderer` draws one pass and does not wait
/// for an async image to arrive.
struct WorkoutShareCardView: View {

    enum Format: String, CaseIterable {
        case story
        case square

        /// Points; three times this in pixels.
        var size: CGSize {
            switch self {
            case .story: CGSize(width: 360, height: 640)
            case .square: CGSize(width: 360, height: 360)
            }
        }

        var title: String {
            switch self {
            case .story: String(localized: "Story")
            case .square: String(localized: "Square")
            }
        }
    }

    let content: ShareCardContent
    var avatar: UIImage?
    let format: Format

    private var isStory: Bool { format == .story }

    var body: some View {
        VStack(alignment: .leading, spacing: isStory ? 20 : 10) {
            appMark
            Spacer(minLength: 0)
            authorRow
            titleBlock
            stats
            highlights
        }
        .padding(isStory ? 28 : 20)
        // Stories lay their own reply bar over the bottom of the image.
        .padding(.bottom, isStory ? 72 : 0)
        .frame(width: format.size.width, height: format.size.height, alignment: .topLeading)
        .background(background)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Pieces

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.35), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .background(.black)
    }

    private var appMark: some View {
        HStack(spacing: 8) {
            Image("AppIconInternalDefaultAsset")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: 6))
            Text("Compound")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var authorRow: some View {
        if content.firstName != nil || avatar != nil {
            HStack(spacing: 10) {
                avatarView
                    .frame(width: isStory ? 44 : 32, height: isStory ? 44 : 32)
                    .clipShape(.circle)
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                if let firstName = content.firstName {
                    Text(firstName)
                        .font(isStory ? .headline : .subheadline.weight(.semibold))
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatar {
            Image(uiImage: avatar)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(.white.opacity(0.2))
                .overlay(
                    Text(content.firstName.map { String($0.prefix(1)) } ?? "")
                        .font(.headline)
                )
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.sessionName)
                .font(.system(size: isStory ? 34 : 24, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(content.dateText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: isStory ? 24 : 16) {
            if let duration = content.durationText {
                stat("Duration", duration)
            }
            if let volume = content.volumeText {
                stat("Volume", volume)
            }
            stat(content.setCount == 1 ? String(localized: "Set") : String(localized: "Sets"), "\(content.setCount)")
        }
    }

    private func stat(_ header: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(header.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: isStory ? 24 : 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Records, then streak, then the weekly count, as on the feed card. The square has room for
    /// two records; the story for all three the feed ever shows.
    @ViewBuilder
    private var highlights: some View {
        let records = Array(content.personalRecordLines.prefix(isStory ? 3 : 2))
        if !records.isEmpty || content.streakText != nil || content.weeklyText != nil {
            FlowLayout(spacing: 6) {
                ForEach(records, id: \.self) { line in
                    capsule("PR: \(line)", systemImage: "trophy.fill", tint: .yellow)
                }
                if let streak = content.streakText {
                    capsule(streak, systemImage: "flame.fill", tint: .orange)
                }
                if let weekly = content.weeklyText {
                    capsule(weekly, systemImage: "calendar", tint: .blue)
                }
            }
        }
    }

    private func capsule(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.15), in: .capsule)
    }
}

#Preview("Story") {
    WorkoutShareCardView(content: .preview, format: .story)
}

#Preview("Square") {
    WorkoutShareCardView(content: .preview, format: .square)
}

extension ShareCardContent {
    /// The card the Dev Settings entry and `STARTSCREEN_SHARE_CARD` show: a mock session read
    /// against the rest of the mock history, so it carries records and a weekly count.
    @MainActor
    static func mock(session: WorkoutSessionModel = WorkoutSessionModel.mocks[0]) -> ShareCardContent {
        make(session: session, author: .mock, history: WorkoutSessionModel.mocks)
    }

    @MainActor
    static var preview: ShareCardContent {
        mock(session: WorkoutSessionModel.mocks.last ?? .mock)
    }
}
