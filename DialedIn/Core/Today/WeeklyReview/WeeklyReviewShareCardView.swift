//
//  WeeklyReviewShareCardView.swift
//  DialedIn
//
//  The Weekly Review as a Stories-sized image, drawn like `WorkoutShareCardView` and rendered the
//  same way. Privacy: numbers only, no name, no body weight, no nutrition.
//

import SwiftUI

struct WeeklyReviewShareCardView: View {

    static let size = WorkoutShareCardView.Format.story.size

    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image("AppIconInternalDefaultAsset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Compound")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Review")
                    .font(.system(size: 34, weight: .bold))
                Text(review.dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text(review.takeaway)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 24) {
                stat("Sessions", review.sessionsText)
                stat("Volume", review.volumeText)
                stat("PRs", "\(review.personalRecords.count)")
            }
            if !review.personalRecords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(review.personalRecords.prefix(3).enumerated()), id: \.offset) { _, record in
                        Label("\(record.exerciseName) \(record.detail)", systemImage: "trophy.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(28)
        .padding(.bottom, 72)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.35), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.black)
        )
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ header: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(header.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @MainActor
    static func render(_ review: WeeklyReview) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyReviewShareCardView(review: review))
        renderer.scale = ShareCardRenderer.scale
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}
