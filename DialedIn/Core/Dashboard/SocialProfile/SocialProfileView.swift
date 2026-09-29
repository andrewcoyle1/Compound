import SwiftUI

struct SocialProfileDelegate {
    let user: UserModel
    var eventParameters: [String: Any]? {
        nil
    }
}

struct SocialProfileView<WorkoutSessionRow: View>: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State var presenter: SocialProfilePresenter
    let delegate: SocialProfileDelegate

    @ViewBuilder var workoutSessionRow: (WorkoutSessionRowDelegate) -> WorkoutSessionRow
    
    var body: some View {
        List {
            profileSection
            if !presenter.isLocked {
                consistencySection
                sessionsSection
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        // Sharing a profile needs a shareable link, and there is no user-profile deep link route (the
        // `compound` scheme has none), so the toolbar carries only the safety menu.
        .toolbar {
            if !presenter.isOwnProfile {
                ToolbarItem(placement: .topBarTrailing) {
                    moreMenu
                }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    private var moreMenu: some View {
        Menu {
            Button(presenter.blockMenuTitle, systemImage: presenter.isBlocked ? "hand.raised.slash" : "hand.raised") {
                presenter.onBlockMenuPressed()
            }
            Button("Report", systemImage: "exclamationmark.bubble") {
                presenter.onReportPressed()
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More actions")
    }

    /// Sat in a plain list row under a "Profile" header that repeated the navigation title, on the
    /// list's own background. It is a card now, like every other surface the app shows.
    private var profileSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Stacked at accessibility sizes: beside an 80pt face and the follow button the
                // name had a third of the row and hyphenated onto three lines.
                AdaptiveStack(spacing: 16) {
                    UserAvatarView(imageUrl: delegate.user.profileImageNameCalculated, size: 80)

                    VStack(alignment: .leading, spacing: 4) {
                        if let name = delegate.user.fullNameCalculated {
                            Text(name)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        UsernameLabel(username: delegate.user.username, font: .subheadline)
                        if presenter.followsYou {
                            Text("Follows you")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        // A date of birth sat here: personal data with no social value.
                        if let streak = presenter.latestStreak {
                            Label("\(streak)-day streak", systemImage: "flame.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                        if let programName = presenter.programName {
                            Text("Following \(programName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let goalText = presenter.weeklyGoalText {
                            Button(goalText, systemImage: "target") { presenter.onWeeklyGoalPressed() }
                                .font(.caption.weight(.medium))
                                .buttonStyle(.borderless)
                                .accessibilityHint("Changes your weekly session goal")
                        }
                    }

                    Spacer(minLength: 0)

                    if presenter.showsFollowButton {
                        FollowButton(state: presenter.followState) {
                            presenter.onFollowButtonPressed()
                        }
                    }
                }

                Divider()

                if presenter.isBlocked {
                    Label("You have blocked this account", systemImage: "hand.raised")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 32) {
                        // An "Activity 1" stat sat here, hardcoded. Nothing counts a user's activity, and
                        // followers/following beside it are real, which made the fake one look real too.
                        StatItem(header: String(localized: "Followers"), value: "\(presenter.followersCount)")
                            .tappableBackground()
                            .anyButton(.press) {
                                presenter.onFollowersPressed()
                            }
                        StatItem(header: String(localized: "Following"), value: "\(presenter.followingCount)")
                            .tappableBackground()
                            .anyButton(.press) {
                                presenter.onFollowingPressed()
                            }
                        Spacer()
                        // A chat button sat here. There is no messaging anywhere in the app — no model, no
                        // manager, no screen — so it was an empty closure over a feature that does not exist.
                    }
                }

                if !presenter.isBlocked, presenter.isLocked {
                    Label("This account is private. Follow it to see its workouts.", systemImage: "lock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !presenter.isBlocked, !presenter.isLocked, !presenter.mutualFollowers.isEmpty {
                    Divider()
                    mutualFollowersImagesSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
            .padding(.horizontal)
            .padding(.bottom, 12)
            .removeListRowFormatting()
        }
        .listSectionMargins(.all, 0)
        .listSectionSeparator(.hidden)
    }
    
    // A "Data" section sat here: Activities, Statistics, Routes, Segments, Best Efforts, Posts and
    // Gear — seven rows, every action an empty closure, with invented subtitles ("This year: 93.0 km",
    // "Puma Deviate Nitro", "Yesterday"). It needs the Strava *read* API, and `StravaManager` is
    // upload-only: authenticate, uploadActivity, disconnect, and no fetch of any kind. Showing
    // someone else's mileage as fact is the worst version of this, so the section is gone rather than
    // emptied. "Posts" was the one row that maps to data the app owns; it is the sessions list
    // below now.

    /// Training days over the last twelve weeks, a square per day.
    private var consistencySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ContributionChart(
                    data: [presenter.consistencySeries],
                    configuration: ChartConfiguration(
                        aggregation: .sum,
                        unit: "workouts",
                        seriesColors: [.orange],
                        goal: 1,
                        accessibilityTitle: "Training days"
                    )
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
            .padding(.horizontal)
            .padding(.bottom, 12)
            .removeListRowFormatting()
        } header: {
            SectionHeaderView(title: String(localized: "Consistency"))
        }
        .listSectionMargins(.vertical, 0)
        .listSectionMargins(.horizontal, 0)
        .listSectionSeparator(.hidden)
    }

    private var sessionsSection: some View {
        Section {
            if presenter.isLoadingSessions && presenter.sessions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .removeListRowFormatting()
            } else if presenter.sessions.isEmpty {
                Text("No workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
                    .padding(.horizontal)
                    .removeListRowFormatting()
            } else {
                ForEach(presenter.sessions) { session in
                    workoutSessionRow(WorkoutSessionRowDelegate(session: session, author: delegate.user))
                        .removeListRowFormatting()
                        .listRowSeparator(.hidden)
                }
            }
        } header: {
            SectionHeaderView(title: String(localized: "Recent Workouts"))
        }
        .listSectionMargins(.top, 0)
        .listSectionMargins(.horizontal, 0)
        .listSectionSeparator(.hidden)
    }

    private var mutualFollowersImagesSection: some View {
        AdaptiveStack(spacing: 8) {
            // The avatars overlap; the label beside them must not, so the negative spacing is
            // scoped to the stack that wants it instead of the whole row.
            HStack(spacing: -10) {
                ForEach(presenter.mutualFollowers.prefix(5)) { user in
                    mutualFollowersImageCircle(user: user)
                }
            }
            .accessibilityHidden(true)

            Text("People you both follow")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("See All")
                .font(.caption)
                .underline()
                .anyButton(.press) {
                    presenter.onMutualFollowersPressed()
                }
        }
    }

    @ViewBuilder
    private func mutualFollowersImageCircle(user: UserModel) -> some View {
        ZStack {
            Circle()
                .fill(colorScheme.backgroundPrimary)

            ImageLoaderView(
                urlString: user.submittedProfileImage ?? "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
        }
        .frame(width: 38, height: 38)
        .overlay(Circle().stroke(colorScheme.backgroundSecondary, lineWidth: 2))
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SocialProfileDelegate(user: .mock)
    
    return RouterView { router in
        builder.socialProfileView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func socialProfileView(router: AnyRouter, delegate: SocialProfileDelegate) -> some View {
        SocialProfileView(
            presenter: SocialProfilePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            workoutSessionRow: { delegate in
                self.workoutSessionRowView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showSocialProfileView(delegate: SocialProfileDelegate) {
        router.showScreen(.push) { router in
            builder.socialProfileView(router: router, delegate: delegate)
        }
    }
    
}
