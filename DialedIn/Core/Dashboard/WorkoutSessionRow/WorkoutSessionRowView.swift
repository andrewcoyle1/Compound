//
//  WorkoutSessionRowView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/02/2026.
//

import SwiftUI

struct WorkoutSessionRowDelegate {
    let session: WorkoutSessionModel
    let author: UserModel
        
    @MainActor
    static var mock: Self {
        Self(session: .mock, author: .mock)
    }
}

struct WorkoutSessionRowView<AuthorHeader: View>: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State var presenter: WorkoutSessionRowPresenter

    @ViewBuilder var authorHeader: (AuthorHeaderDelegate) -> AuthorHeader
    
    // MARK: - Body

    /// A `Section` nested inside the feed's own section, on a square edge-to-edge fill. Every other
    /// surface in the app is a rounded, inset card, so the feed was the one place that read as a
    /// wall of text rather than a stack of cards.
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            authorHeader(AuthorHeaderDelegate(author: presenter.author, date: presenter.session.dateCreated))
            sessionContent
            Divider()
            footerBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardSurface()
        .padding(.horizontal)
        .padding(.bottom, Spacing.m)
    }

    // MARK: - Session Title and Stats

    private var sessionContent: some View {
        VStack {
            sessionTitleAndStats
            exerciseList
            authorNote
        }
        // One VoiceOver stop for the title, highlights, stats and exercises; the author header
        // above and the like, comment, share and menu controls below stay separate stops.
        .accessibilityElement(children: .combine)
        .anyButton {
            presenter.onWorkoutPressed()
        }
        .accessibilityHint("Opens the workout")

    }
    
    private var sessionTitleAndStats: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(presenter.session.name)
                .font(.sectionTitle)
            highlights
            // Four stats side by side stop fitting at the accessibility text sizes.
            AdaptiveStack(verticalAlignment: .top, spacing: dynamicTypeSize.isAccessibilitySize ? Spacing.s : Spacing.xl) {
                Stat(value: presenter.session.exercises.count.formatted(), label: String(localized: "Exercises"), size: .small)
                Stat(value: presenter.workingSetCount.formatted(), label: String(localized: "Sets"), size: .small)
                if let volume = presenter.volumeText {
                    Stat(value: volume, label: String(localized: "Volume"), size: .small)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                if let duration = presenter.durationText {
                    Stat(value: duration, label: String(localized: "Duration"), size: .small, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                }
            }
        }
    }

    // MARK: - Highlights

    /// Records first, then the streak, then the weekly count, each a small capsule. Wraps rather
    /// than truncates: three PRs do not fit on one line of a phone. The flame is the streak's; the
    /// weekly count had it before streaks were shown and moved to a calendar.
    @ViewBuilder
    private var highlights: some View {
        if !presenter.personalRecords.isEmpty || presenter.streakText != nil || presenter.weeklyWorkoutText != nil {
            FlowLayout(spacing: Spacing.xs) {
                ForEach(presenter.personalRecords, id: \.exerciseName) { record in
                    highlightCapsule("PR: \(record.exerciseName) \(record.detail)", systemImage: Symbol.personalRecord, tint: .personalRecord)
                }
                if let streak = presenter.streakText {
                    highlightCapsule(streak, systemImage: Symbol.streak, tint: Color.Metric.workouts)
                }
                if let weekly = presenter.weeklyWorkoutText {
                    highlightCapsule(weekly, systemImage: Symbol.calendar, tint: Color.Metric.exercises)
                }
            }
        }
    }

    private func highlightCapsule(_ text: String, systemImage: String, tint: Color) -> some View {
        // An `HStack`, not a `Label`: inside the card's tappable content the label rendered its
        // icon and dropped its title.
        HStack(spacing: Spacing.xs) {
            // The text says what the capsule is; the icon and tint only repeat it.
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.primary)
        }
        .font(.label)
        .fontWeight(.medium)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(Color.tintedSurface(tint), in: .capsule)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(presenter.session.exercises) { exercise in
                AdaptiveStack(spacing: 0) {
                    Text(exercise.name)
                        .font(.rowDetail)
                    Spacer(minLength: Spacing.s)
                    Text(presenter.setsDescription(for: exercise))
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
    }

    /// Collapsed to two lines; the whole note is on the session detail the card opens.
    @ViewBuilder
    private var authorNote: some View {
        if let note = presenter.authorNote {
            Label(note, systemImage: Symbol.note)
                .font(.label)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Button {
                presenter.onLikeButtonPressed()
            } label: {
                Label("\(presenter.likeCount)", systemImage: presenter.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(presenter.isLiked ? Color.accentColor : Color.secondary)
            .accessibilityLabel(presenter.isLiked ? String(localized: "Unlike") : String(localized: "Like"))
            .accessibilityValue(presenter.likeCount == 1 ? String(localized: "1 like") : String(localized: "\(presenter.likeCount) likes"))
            Button {
                presenter.onCommentButtonPressed()
            } label: {
                Image(systemName: "bubble")
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Comments")
            ShareLink(item: presenter.shareSummary) {
                Image(systemName: Symbol.share)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Share workout")
            Menu {
                Button("Save as Template", systemImage: "square.and.arrow.down") {
                    presenter.onSaveAsTemplatePressed()
                }
                if let template = presenter.shareableTemplate {
                    Button("Share Workout with Friends", systemImage: "paperplane") {
                        presenter.onShareTemplatePressed(template)
                    }
                }
                Menu("Share Image", systemImage: "photo") {
                    ForEach(WorkoutShareCardView.Format.allCases, id: \.self) { format in
                        Button(format.title) {
                            presenter.onShareImagePressed(format: format)
                        }
                    }
                }
                if let link = presenter.webLink {
                    Button("Copy Link", systemImage: "link") {
                        presenter.onCopyLinkPressed(link)
                    }
                }
                if presenter.canReport {
                    Button("Report Workout", systemImage: "exclamationmark.bubble") {
                        presenter.onReportPressed()
                    }
                }
            } label: {
                Image(systemName: Symbol.more)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("More actions")
        }
        .font(.rowDetail)
        // Three actions of equal weight. The like button turns accented once it is on, so the "on"
        // state reads at a glance instead of only through a filled-vs-outline thumb.
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        List {
            builder.workoutSessionRowView(router: router, delegate: .mock)
        }
    }
}

extension CoreBuilder {
    func workoutSessionRowView(router: AnyRouter, delegate: WorkoutSessionRowDelegate) -> some View {
        WorkoutSessionRowView(
            presenter: WorkoutSessionRowPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            authorHeader: { delegate in
                self.authorHeaderView(router: router, delegate: delegate)
            }
        )
    }
}
