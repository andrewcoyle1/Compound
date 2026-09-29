import SwiftUI

struct DashboardDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

/// Gutter between the Dashboard's carousel cards, and between a card and the screen edge. Matches
/// the Analytics tab's header carousel, which the two screens are read one after the other.
private let carouselCardSpacing: CGFloat = 16

/// How much of the next card shows past the trailing edge of the current one, so the carousel
/// reads as scrollable without page dots.
private let carouselCardPeek: CGFloat = 32

struct DashboardView<
    WorkoutSessionRow: View,
    TodaysCard: View,
    StreakCard: View
>: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutMode) private var layoutMode
    /// The card titles grow with Dynamic Type; a fixed 30pt clipped them at accessibility sizes.
    @ScaledMetric(relativeTo: .headline) private var carouselTitleHeight = DashboardCard<EmptyView>.titleHeight
    @State var presenter: DashboardPresenter
    let delegate: DashboardDelegate

    let profileTransitionId: String = "profile_button_transition"
    
    @ViewBuilder var workoutSessionRow: (WorkoutSessionRowDelegate) -> WorkoutSessionRow
    @ViewBuilder var todaysWorkoutCard: (TodaysWorkoutCardDelegate) -> TodaysCard
    @ViewBuilder var workoutStreakCard: (WorkoutStreakDelegate) -> StreakCard
    
    @Namespace private var namespace
    
    var body: some View {
        List {
            if presenter.needsUsername { UsernameBannerView { presenter.onPickUsernamePressed() } }
            cardsSection
            workoutFeedSection
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Dashboard")
        .navigationSubtitle(Date.now.formatted(date: .abbreviated, time: .omitted))
        .minimizingLargeTitleBar()
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
        .task {
            await presenter.loadNotifications()
            await presenter.loadSuggestedUsers()
            await presenter.loadChallenges()
        }
    }
    
    /// The carousel was a paged `TabView` with dots, sized by a `+ 60` guess and showing exactly one
    /// card however wide the window was. The Analytics tab's header carousel is a view-aligned
    /// scroll that sizes its cards from the container and shows two of them in split view, so the
    /// two screens now snap and breathe the same way.
    private var cardsSection: some View {
        Section {
            // The width is measured rather than taken from `containerRelativeFrame`, which resolves
            // against the scroll view's container and so did not agree with the gutters the content
            // actually had: the cards came out a little wider than their slot, centred, and the
            // overflow pushed the first card's title off the leading edge.
            GeometryReader { proxy in
                carousel(cardWidth: cardWidth(forContainerWidth: proxy.size.width))
            }
            .frame(height: carouselHeight)
            .removeListRowFormatting()
        }
        .listSectionMargins(.all, 0)
        .listSectionSeparator(.hidden)
    }

    private var carouselHeight: CGFloat {
        DashboardCard<EmptyView>.contentHeight + carouselTitleHeight
    }

    /// A single card deliberately stops short of the full width. The paged `TabView` this replaced
    /// had dots to say there was more than one card; a full-width card in a scroll view says
    /// nothing at all, so the next card's edge peeks instead. Two cards share the width in split
    /// view, where there is room for both.
    private func cardWidth(forContainerWidth width: CGFloat) -> CGFloat {
        let available = width - (carouselCardSpacing * 2)
        let cardWidth = layoutMode == .splitView
            ? (available - carouselCardSpacing) / 2
            : available - carouselCardPeek
        return max(cardWidth, 0)
    }

    private func carousel(cardWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: carouselCardSpacing) {
                if let todaysWorkoutTemplate = presenter.todaysWorkoutTemplate {
                    todaysWorkoutCard(
                        TodaysWorkoutCardDelegate(todaysWorkoutTemplate: todaysWorkoutTemplate)
                    )
                    .frame(width: cardWidth)
                }

                workoutStreakCard(WorkoutStreakDelegate())
                    .frame(width: cardWidth)

                nutritionCard
                    .frame(width: cardWidth)
            }
            .padding(.horizontal, carouselCardSpacing)
            .frame(height: carouselHeight)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private var nutritionCard: some View {
        NutritionCard(
            calories: presenter.nutritionTotals?.calories ?? 0,
            calorieTarget: presenter.nutritionTarget?.calories ?? 2000,
            proteinGrams: presenter.nutritionTotals?.proteinGrams ?? 0,
            proteinTarget: presenter.nutritionTarget?.proteinGrams ?? 150,
            carbGrams: presenter.nutritionTotals?.carbGrams ?? 0,
            carbTarget: presenter.nutritionTarget?.carbGrams ?? 250,
            fatGrams: presenter.nutritionTotals?.fatGrams ?? 0,
            fatTarget: presenter.nutritionTarget?.fatGrams ?? 70,
            onLogMealTapped: { presenter.onLogMealPressed() }
        )
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
            // MARK: - WeeklyReview
            if presenter.showsWeeklyReviewCard { WeeklyReviewCard { presenter.onWeeklyReviewPressed() }.removeListRowFormatting().listRowSeparator(.hidden) }
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
                    .padding(.vertical, 32)
                    .removeListRowFormatting()
                    .listRowSeparator(.hidden)
            } else if presenter.feedSessions.isEmpty {
                ContentUnavailableView {
                    Label("No Activity Yet", systemImage: "figure.run")
                } description: {
                    Text("Follow athletes you admire. Progress is more fun shared.")
                } actions: {
                    Button("Find People") {
                        presenter.onFindPeoplePressed()
                    }
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
        
        #if DEV || MOCK
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        #endif
        
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onPushNotificationsPressed()
            } label: {
                Image(systemName: "bell")
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
    let delegate = DashboardDelegate()
    
    return RouterView { router in
        builder.dashboardView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func dashboardView(router: AnyRouter, delegate: DashboardDelegate) -> some View {
        DashboardView(
            presenter: DashboardPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate,
            workoutSessionRow: { delegate in
                self.workoutSessionRowView(
                    router: router,
                    delegate: delegate
                )
            },
            todaysWorkoutCard: { cardDelegate in
                self.todaysWorkoutCard(
                    router: router,
                    delegate: cardDelegate
                )
            },
            workoutStreakCard: { delegate in
                self.workoutStreakCardView(
                    router: router,
                    delegate: delegate
                )
            }
        )
    }
    
}

extension CoreRouter {
    
    func showDashboardView(delegate: DashboardDelegate) {
        router.showScreen(.push) { router in
            builder.dashboardView(router: router, delegate: delegate)
        }
    }
    
}

// MARK: - Challenges

extension DashboardView {
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
