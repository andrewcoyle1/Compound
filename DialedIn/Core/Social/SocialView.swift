import SwiftUI

struct SocialDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

/// Everyone else: the feed, the circle, challenges, and finding people. The user's own day is on
/// Today.
struct SocialView<WorkoutSessionRow: View>: View {

    @State var presenter: SocialPresenter
    let delegate: SocialDelegate

    let profileTransitionId: String = "profile_button_transition"

    @ViewBuilder var workoutSessionRow: (WorkoutSessionRowDelegate) -> WorkoutSessionRow

    @Namespace private var namespace

    var body: some View {
        List {
            if presenter.isSearchPresented || presenter.peopleSearch.isSearching {
                PeopleSearchResults(
                    search: presenter.peopleSearch,
                    followState: { presenter.followState(for: $0) },
                    onFollowPressed: { presenter.onFollowButtonPressed(user: $0) },
                    onPersonPressed: { presenter.onPersonPressed(user: $0) },
                    onInviteFriendPressed: { presenter.onInviteFriendPressed() },
                    onEnterInviteCodePressed: { presenter.onEnterInviteCodePressed() }
                )
            } else {
                if presenter.needsUsername { UsernameBannerView { presenter.onPickUsernamePressed() } }
                workoutFeedSection
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Social")
        .minimizingLargeTitleBar()
        .searchable(
            text: $presenter.peopleSearch.query,
            isPresented: $presenter.isSearchPresented,
            placement: .toolbar,
            prompt: Text("Name or @username")
        )
        .onChange(of: presenter.peopleSearch.query) {
            presenter.peopleSearch.onQueryChanged()
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .toolbar { toolbarContent }
        // A push tap about a session — see `DeepLink.post()`.
        .onNotificationReceived(name: Constants.openWorkoutSession) { notification in
            presenter.onOpenWorkoutSessionNotificationReceived(notification)
        }
        // A follow-request push tap — see `DeepLink.post()`.
        .onNotificationReceived(name: Constants.openNotifications) { _ in presenter.onPushNotificationsPressed() }
        .onNotificationReceived(name: Constants.acceptInvite) { presenter.onAcceptInviteNotificationReceived($0) }
        // A small sheet rather than an alert with a text field: an alert is for a problem, and
        // this is a task the person chose.
        .sheet(isPresented: $presenter.isEnteringInviteCode) {
            InviteCodeSheet(
                code: $presenter.inviteCodeInput,
                canJoin: presenter.canJoinWithInviteCode,
                onClose: { presenter.onInviteCodeClosePressed() },
                onJoin: { presenter.onInviteCodeJoinPressed() }
            )
        }
        .task {
            await presenter.loadNotifications()
            await presenter.loadSuggestedUsers()
            await presenter.loadChallenges()
        }
    }

    /// One section for the whole feed. Every row used to be wrapped in a `Section` of its own so
    /// that the first could carry the header, which gave each row the full section inset and a
    /// header that only appeared when the feed was non-empty in exactly the right way.
    private var workoutFeedSection: some View {
        Section {
            if let summary = presenter.weeklySummary {
                CircleWeeklySummaryCard(summary: summary) { presenter.onWeeklySummaryDismissed() }
                    .removeListRowFormatting()
                    .listRowSeparator(.hidden)
            }
            // MARK: - RatingReferral
            if presenter.showsInviteCard { InviteFriendCard { presenter.onInviteCardPressed() } onDismiss: { presenter.onInviteCardDismissed() }.removeListRowFormatting().listRowSeparator(.hidden) }
            if !presenter.circleMembers.isEmpty {
                CircleActivityStripView(
                    members: presenter.circleMembers,
                    onMemberPressed: { presenter.onCircleMemberPressed($0) },
                    onNudgePressed: { presenter.onNudgePressed($0) },
                    onSetGoalPressed: presenter.showsWeeklyGoalPrompt ? { presenter.onSetWeeklyGoalPressed() } : nil
                )
                .removeListRowFormatting()
                .listRowSeparator(.hidden)
                CircleLeaderboardView(
                    standings: presenter.circleStandings,
                    currentUserId: presenter.currentUserId,
                    onRowPressed: { presenter.onLeaderboardRowPressed($0) }
                )
                .removeListRowFormatting()
                .listRowSeparator(.hidden)
            }
            // MARK: - Challenges
            if presenter.showsChallengesSection { challengesSection }
            if presenter.isFeedLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
                    .removeListRowFormatting()
                    .listRowSeparator(.hidden)
            } else if presenter.feedSessions.isEmpty {
                ContentUnavailableView {
                    Label("No Activity Yet", systemImage: Symbol.friends)
                } description: {
                    Text("Follow athletes you admire. Progress is more fun shared.")
                } actions: {
                    Button("Find People") {
                        presenter.onFindPeoplePressed()
                    }
                    .buttonStyle(.borderedProminent)
                    // The label is drawn on the accent, so it needs onAccent, not the accent's own colour.
                    .foregroundStyle(.onAccent)
                }
                .removeListRowFormatting()
                suggestedPeopleRows
            } else {
                ForEach(presenter.feedSessions) { session in
                    if let author = presenter.author(for: session) {
                        workoutSessionRow(WorkoutSessionRowDelegate(session: session, author: author))
                            .removeListRowFormatting()
                            // The rows are separate cards with a gap between them; a divider in that
                            // gap draws a hairline floating between two rounded surfaces.
                            .listRowSeparator(.hidden)
                    }
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Workout Feed"),
                actionTitle: String(localized: "Find People"),
                onActionPressed: presenter.feedSessions.isEmpty ? nil : { presenter.onFindPeoplePressed() }
            )
        }
        .listSectionMargins(.top, 0)
        // The section's default horizontal margin sat outside the cards' own padding, so the feed
        // cards were inset further than the carousel cards above them. The cards bring their own
        // gutter; the section should not add a second one.
        .listSectionMargins(.horizontal, 0)
        .listSectionSeparator(.hidden)
    }
    
    /// A handful of people to follow, so a new user has a feed by the time they scroll back up.
    @ViewBuilder
    private var suggestedPeopleRows: some View {
        ForEach(presenter.visibleSuggestedUsers) { user in
            UserRowView(user: user) {
                FollowButton(state: presenter.followState(for: user)) {
                    presenter.onFollowButtonPressed(user: user)
                }
            }
            .tappableBackground()
            .anyButton(.highlight) {
                presenter.onSuggestedUserPressed(user: user)
            }
            .padding(.horizontal)
            .removeListRowFormatting()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onPushNotificationsPressed()
            } label: {
                Image(systemName: Symbol.notifications)
            }
            .accessibilityLabel("Notifications")
            .badge(presenter.bellBadgeCount)
        }
        
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            ProfileButton(
                action: {
                    presenter.onProfilePressed(transitionId: profileTransitionId, namespace: namespace)
                },
                imageUrl: presenter.userImageUrl
            )
            .matchedTransitionSource(id: profileTransitionId, in: namespace)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SocialDelegate()
    
    return RouterView { router in
        builder.socialView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func socialView(router: AnyRouter, delegate: SocialDelegate) -> some View {
        SocialView(
            presenter: SocialPresenter(
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

// MARK: - Challenges

extension SocialView {
    var challengesSection: some View {
        ChallengesDashboardSection(
            cards: presenter.challengeCards,
            currentUserId: presenter.currentUserId,
            onCardPressed: { presenter.onChallengePressed($0) },
            onCreatePressed: { presenter.onCreateChallengePressed() }
        )
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }
}
