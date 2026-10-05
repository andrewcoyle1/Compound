import SwiftUI

struct SocialProfileDelegate {
    let user: UserModel
    /// The profile button's full-screen cover, which needs its own close button.
    var isPresentedModally = false
    var eventParameters: [String: Any]? {
        nil
    }
}

struct SocialProfileView<WorkoutSessionRow: View>: View {
    
    @State var presenter: SocialProfilePresenter
    let delegate: SocialProfileDelegate

    @ViewBuilder var workoutSessionRow: (WorkoutSessionRowDelegate) -> WorkoutSessionRow

    @ScaledMetric(relativeTo: .caption) private var avatarSide = ControlSize.thumbnail
    
    var body: some View {
        List {
            profileSection
            if !presenter.isLocked {
                tabPicker
                switch presenter.selectedTab {
                case .progress:
                    thisWeekSection
                    consistencySection
                    stravaSection
                case .activities:
                    sessionsSection
                }
            }
        }
        .reducedMotionAnimation(.standard, value: presenter.selectedTab)
        .navigationTitle(presenter.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            if delegate.isPresentedModally {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        presenter.onDismissPressed()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if presenter.isOwnProfile {
                    Button("Settings", systemImage: Symbol.settings) {
                        presenter.onSettingsPressed()
                    }
                } else {
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
            Button("Report…", systemImage: "exclamationmark.bubble") {
                presenter.onReportPressed()
            }
        } label: {
            Image(systemName: Symbol.more)
        }
        .accessibilityLabel("More actions")
    }

    /// Sat in a plain list row under a "Profile" header that repeated the navigation title, on the
    /// list's own background. It is a card now, like every other surface the app shows.
    private var profileSection: some View {
        let user = presenter.user ?? delegate.user
        return Section {
            VStack(alignment: .leading, spacing: Spacing.l) {
                // Stacked at accessibility sizes: beside an 80pt face and the follow button the
                // name had a third of the row and hyphenated onto three lines.
                AdaptiveStack(spacing: Spacing.l) {
                    UserAvatarView(imageUrl: user.profileImageNameCalculated, size: 80)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        if let name = user.fullNameCalculated {
                            Text(name)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        if let count = presenter.workoutCount {
                            Text("\(count) workouts")
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                        if presenter.followsYou {
                            Text("Follows you")
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                        // A date of birth sat here: personal data with no social value.
                        if let streak = presenter.latestStreak {
                            Label("\(streak)-week streak", systemImage: Symbol.streak)
                                .font(.label)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Metric.workouts)
                        }
                        if let mesocycleName = presenter.mesocycleName {
                            Text("Following \(mesocycleName)")
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                        if let goalText = presenter.weeklyGoalText {
                            Button {
                                presenter.onWeeklyGoalPressed()
                            } label: {
                                Label(goalText, systemImage: Symbol.goal)
                                    .tapTarget()
                            }
                            .font(.label)
                            .fontWeight(.medium)
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
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: Spacing.xxl) {
                        // An "Activity 1" stat sat here, hardcoded. Nothing counts a user's activity, and
                        // followers/following beside it are real, which made the fake one look real too.
                        Stat(value: presenter.followersCount.formatted(), label: String(localized: "Followers"), size: .small)
                            .tapTarget()
                            .tappableBackground()
                            .anyButton(.press) {
                                presenter.onFollowersPressed()
                            }
                        Stat(value: presenter.followingCount.formatted(), label: String(localized: "Following"), size: .small)
                            .tapTarget()
                            .tappableBackground()
                            .anyButton(.press) {
                                presenter.onFollowingPressed()
                            }
                        Spacer()
                        // A chat button sat here. There is no messaging anywhere in the app — no model, no
                        // manager, no screen — so it was an empty closure over a feature that does not exist.
                    }
                }

                if presenter.isOwnProfile {
                    ownProfileActions
                }

                if !presenter.isBlocked, presenter.isLocked {
                    Label("This account is private. Follow it to see its workouts.", systemImage: "lock")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }

                if !presenter.isBlocked, !presenter.isLocked, !presenter.mutualFollowers.isEmpty {
                    Divider()
                    mutualFollowersImagesSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .cardSurface()
            .padding(.horizontal)
            .padding(.bottom, Spacing.m)
            .removeListRowFormatting()
        }
        .listSectionMargins(.all, 0)
        .listSectionSeparator(.hidden)
    }
    
    /// Strava's pair under the counts: what the owner does with their own profile.
    private var ownProfileActions: some View {
        HStack(spacing: Spacing.s) {
            Button {
                presenter.onEditProfilePressed()
            } label: {
                Text("Edit Profile")
                    .frame(maxWidth: .infinity)
            }
            Button {
                Task { await presenter.onShareProfilePressed() }
            } label: {
                Text("Share Profile")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.rowDetail.weight(.semibold))
        .buttonStyle(.bordered)
    }

    private var tabPicker: some View {
        Section {
            Picker("Profile", selection: $presenter.selectedTab) {
                ForEach(SocialProfilePresenter.Tab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, Spacing.m)
            .removeListRowFormatting()
        }
        .listSectionMargins(.all, 0)
        .listSectionSeparator(.hidden)
    }

    private var thisWeekSection: some View {
        Section {
            HStack(spacing: Spacing.xxl) {
                Stat(value: presenter.thisWeekWorkouts.formatted(), label: String(localized: "Workouts"), size: .small)
                Stat(value: Format.duration(presenter.thisWeekDuration), label: String(localized: "Time"), size: .small)
                Stat(value: presenter.thisWeekVolumeText, label: String(localized: "Volume"), size: .small)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .cardSurface()
            .padding(.horizontal)
            .padding(.bottom, Spacing.m)
            .removeListRowFormatting()
        } header: {
            SectionHeaderView(title: String(localized: "This Week"))
        }
        .listSectionMargins(.vertical, 0)
        .listSectionMargins(.horizontal, 0)
        .listSectionSeparator(.hidden)
    }

    /// The owner's year on Strava and their latest activities. Empty, and so absent, on anyone
    /// else's profile: Strava's terms keep an athlete's data to the athlete.
    @ViewBuilder
    private var stravaSection: some View {
        if let year = presenter.stravaYear {
            Section {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack(spacing: Spacing.xxl) {
                        Stat(value: year.count.formatted(), label: String(localized: "Activities"), size: .small)
                        Stat(value: Format.distance(meters: year.distanceMeters, unit: presenter.distanceUnit), label: String(localized: "Distance"), size: .small)
                        Stat(value: Format.duration(year.movingTime), label: String(localized: "Time"), size: .small)
                        Spacer(minLength: 0)
                    }
                    ForEach(presenter.recentStravaActivities) { activity in
                        stravaActivityRow(activity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardSurface()
                .padding(.horizontal)
                .padding(.bottom, Spacing.m)
                .removeListRowFormatting()
            } header: {
                SectionHeaderView(title: String(localized: "Strava This Year"))
            }
            .listSectionMargins(.vertical, 0)
            .listSectionMargins(.horizontal, 0)
            .listSectionSeparator(.hidden)
        }
    }

    /// Strava's brand guidelines ask for "View on Strava" on a link to an activity.
    @ViewBuilder
    private func stravaActivityRow(_ activity: StravaImportedActivity) -> some View {
        let detail = [
            activity.startDate.formatted(date: .abbreviated, time: .omitted),
            activity.distance > 0 ? Format.distance(meters: activity.distance, unit: presenter.distanceUnit) : nil,
            Format.duration(TimeInterval(activity.movingTime))
        ].compactMap { $0 }.joined(separator: " · ")
        if let url = activity.stravaURL {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(activity.name)
                        .font(.rowTitle)
                    Text(detail)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                    Text("View on Strava")
                        .font(.label)
                        .foregroundStyle(.tint)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    /// Training days over the last twelve weeks, a square per day.
    private var consistencySection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ContributionChart(
                    data: [presenter.consistencySeries],
                    configuration: ChartConfiguration(
                        aggregation: .sum,
                        unit: "workouts",
                        seriesColors: [Color.Metric.workouts],
                        goal: 1,
                        accessibilityTitle: "Training days"
                    )
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .cardSurface()
            .padding(.horizontal)
            .padding(.bottom, Spacing.m)
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
            } else if presenter.loadSessionsFailed {
                ContentUnavailableView {
                    Label("Unable to Load Workouts", systemImage: Symbol.warning)
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Try Again") {
                        presenter.onRetryLoadSessionsPressed(delegate: delegate)
                    }
                }
                .removeListRowFormatting()
            } else if presenter.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: Symbol.workout)
                } description: {
                    Text("Finished workouts show up here.")
                }
                .removeListRowFormatting()
            } else {
                ForEach(presenter.sessions) { session in
                    workoutSessionRow(WorkoutSessionRowDelegate(session: session, author: presenter.user ?? delegate.user))
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
        AdaptiveStack(spacing: Spacing.s) {
            // The avatars overlap; the label beside them must not, so the negative spacing is
            // scoped to the stack that wants it instead of the whole row.
            HStack(spacing: -Spacing.m) {
                ForEach(presenter.mutualFollowers.prefix(5)) { user in
                    mutualFollowersImageCircle(user: user)
                }
            }
            .accessibilityHidden(true)

            Text("People you both follow")
                .font(.label)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                presenter.onMutualFollowersPressed()
            } label: {
                Text("See All")
                    .tapTarget()
            }
            .font(.label)
            .foregroundStyle(.tint)
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func mutualFollowersImageCircle(user: UserModel) -> some View {
        ZStack {
            Circle()
                .fill(.surface)

            ImageLoaderView(
                urlString: user.submittedProfileImage ?? "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
        }
        .frame(width: avatarSide, height: avatarSide)
        .overlay(Circle().stroke(.canvas, lineWidth: 2))
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

    /// The tabs' profile button: the reader's own profile, zooming out of the button.
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) {
        guard let user = builder.interactor.currentUser else { return }
        router.showScreenWithZoomTransition(
            .fullScreenCover,
            transitionID: transitionId,
            namespace: namespace) { router in
                builder.socialProfileView(router: router, delegate: SocialProfileDelegate(user: user, isPresentedModally: true))
            }
    }

}
