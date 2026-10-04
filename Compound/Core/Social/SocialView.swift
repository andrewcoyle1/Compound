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
                // One pattern for every block: each card, and each section header, brings its own
                // inner padding, 16 pt gutter and bottom gap (as the shared `WorkoutSessionRowView`
                // does), so the list adds none — no insets, no separators, no section margins.
                Group {
                    Section {
                        if presenter.needsUsername {
                            UsernameBannerView { presenter.onPickUsernamePressed() }
                        }
                        if let summary = presenter.weeklySummary {
                            CircleWeeklySummaryCard(summary: summary) { presenter.onWeeklySummaryDismissed() }
                        }
                        if presenter.showsInviteCard {
                            InviteFriendCard { presenter.onInviteCardPressed() } onDismiss: { presenter.onInviteCardDismissed() }
                        }
                    }

                    if !presenter.circleMembers.isEmpty {
                        Section {
                            CircleLeaderboardView(
                                standings: presenter.circleStandings,
                                currentUserId: presenter.currentUserId,
                                onRowPressed: { presenter.onLeaderboardRowPressed($0) }
                            )
                        }
                    }

                    if presenter.showsChallengesSection {
                        ChallengesDashboardSection(
                            cards: presenter.challengeCards,
                            currentUserId: presenter.currentUserId,
                            onCardPressed: { presenter.onChallengePressed($0) },
                            onCreatePressed: { presenter.onCreateChallengePressed() }
                        )
                    }

                    workoutFeedSection
                }
                .removeListRowFormatting()
                // Cards sit apart with a gap; a divider in it draws a hairline between two surfaces.
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                // The margin would sit outside each card's own gutter and inset it twice.
                .listSectionMargins(.horizontal, 0)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Social")
        .minimizingLargeTitleBar()
        .searchable(
            text: $presenter.peopleSearch.query,
            isPresented: $presenter.isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
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
        .safeAreaBar(edge: .top) {
            CircleActivityStripView(
                members: presenter.circleMembers,
                onMemberPressed: { presenter.onCircleMemberPressed($0) },
                onNudgePressed: { presenter.onNudgePressed($0) },
                onSetGoalPressed: presenter.showsWeeklyGoalPrompt ? { presenter.onSetWeeklyGoalPressed() } : nil
            )
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
            if presenter.isFeedLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
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
                suggestedPeopleRows
            } else {
                ForEach(presenter.feedSessions) { session in
                    if let author = presenter.author(for: session) {
                        workoutSessionRow(WorkoutSessionRowDelegate(session: session, author: author))
                    }
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Workout Feed"),
                actionTitle: String(localized: "Find People"),
                onActionPressed: presenter.feedSessions.isEmpty ? nil : { presenter.onFindPeoplePressed() }
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
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
