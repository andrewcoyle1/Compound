import SwiftUI

@Observable
@MainActor
class DashboardPresenter {
    
    private let interactor: DashboardInteractor
    private let router: DashboardRouter
    private let followFlow: FollowFlow
    
    private(set) var nutritionTotals: DailyMacroTarget?
    private(set) var nutritionTarget: DailyMacroTarget?

    var activityNotifications: [ActivityNotificationModel] {
        interactor.activityNotifications
    }

    /// The bell's badge: unread activity plus follow requests waiting on an answer, matching the tab.
    var bellBadgeCount: Int {
        NotificationGrouping.unreadGroupCount(activityNotifications) + interactor.incomingFollowRequests.count
    }
    
    /// What the feed shows: finished workouts, newest first, each one attributable to a person.
    ///
    /// The same rule has to apply to both halves. Only the user's own sessions used to be filtered,
    /// so a followed athlete's workout appeared the moment they started it, and the rest days a
    /// program pre-creates for the days ahead were posted to the feed as if they had already
    /// happened. A session with no resolvable author is dropped here rather than in the view, so an
    /// empty feed is recognised as empty instead of drawing a header over nothing.
    ///
    /// A blocked author's sessions are dropped too — blocking unfollows, but the following sync can
    /// still hold their sessions until it next emits.
    var feedSessions: [WorkoutSessionModel] {
        let combined = interactor.workoutSessions + interactor.followingWorkoutSessions
        let reader = interactor.currentUser
        return combined
            .filter { $0.endedAt != nil && !$0.isRestDay && author(for: $0) != nil }
            .filter { !(reader?.hasBlocked($0.authorId) ?? false) }
            .filter { !$0.isHidden(from: reader?.userId) }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    /// Who the user has nudged today. Held here rather than read through the interactor on every
    /// render because the log lives in UserDefaults, which the view cannot observe; refreshed on
    /// each appearance so it rolls over with the day.
    private(set) var nudgedUserIds: Set<String> = []

    /// The circle strip: everyone the user follows plus the user, trained-today first, then by
    /// name. Empty — and so hidden — when the user follows nobody, since a strip of one is just
    /// the user's own face. A blocked account is left out for the same reason as in the feed.
    var circleMembers: [CircleMember] {
        guard let reader = interactor.currentUser else { return [] }
        let followed = interactor.followingUsers.filter { !reader.hasBlocked($0.userId) && $0.userId != reader.userId }
        guard !followed.isEmpty else { return [] }

        let trainedIds = Set(
            (interactor.workoutSessions + interactor.followingWorkoutSessions)
                .filter { session in
                    guard let endedAt = session.endedAt else { return false }
                    return !session.isRestDay && session.deletedAt == nil && Calendar.current.isDateInToday(endedAt)
                }
                .map(\.authorId)
        )
        return ([reader] + followed)
            .map { user in
                let trained = trainedIds.contains(user.userId)
                return CircleMember(
                    user: user,
                    trainedToday: trained,
                    canNudge: !trained && user.userId != reader.userId && !nudgedUserIds.contains(user.userId)
                )
            }
            .map { withWeeklyProgress($0, readerId: reader.userId) }
            .sorted { lhs, rhs in
                if lhs.trainedToday != rhs.trainedToday { return lhs.trainedToday }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func onCircleMemberPressed(_ member: CircleMember) {
        interactor.trackEvent(event: Event.circleMemberPressed)
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: member.user))
    }

    /// Greys the button out at once so a second tap cannot send a second nudge, and gives it back
    /// if the write fails.
    func onNudgePressed(_ member: CircleMember) {
        let userId = member.user.userId
        guard member.canNudge, !nudgedUserIds.contains(userId) else { return }
        interactor.trackEvent(event: Event.nudgePressed)
        interactor.playHaptic(option: .light)
        nudgedUserIds.insert(userId)
        Task {
            do {
                try await interactor.nudgeUser(userId: userId)
            } catch {
                nudgedUserIds.remove(userId)
                router.showSimpleAlert(title: String(localized: "Unable to nudge \(member.name)"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// People to follow, shown only under the empty feed. Loaded once per appearance of that
    /// state; a person the reader follows from here drops out of the list.
    private(set) var suggestedUsers: [UserModel] = []

    var visibleSuggestedUsers: [UserModel] {
        let following = Set(interactor.currentUser?.followingIds ?? [])
        return suggestedUsers.filter { !following.contains($0.userId) }
    }

    func followState(for user: UserModel) -> FollowState {
        followFlow.state(for: user)
    }

    func loadSuggestedUsers() async {
        guard feedSessions.isEmpty else { return }
        // Silent: suggestions are a background extra; none is the right fallback.
        suggestedUsers = (try? await interactor.fetchSuggestedUsers()) ?? []
    }

    /// A push tap about a session, relayed by the tab bar once it has selected this tab. Best
    /// effort: if the session cannot be fetched the user is simply left on the Dashboard.
    func onOpenWorkoutSessionNotificationReceived(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            case .session(let id, let authorId, let openComments)? = DeepLink(pushUserInfo: userInfo)
        else { return }
        Task {
            // Silent: best-effort push tap-through, documented above.
            guard let session = try? await interactor.fetchWorkoutSession(id: id, authorId: authorId) else { return }
            let delegate = WorkoutSessionDetailDelegate(workoutSession: session)
            if openComments {
                router.showWorkoutSessionThread(delegate: delegate)
            } else {
                router.showWorkoutSessionDetailView(delegate: delegate)
            }
        }
    }

    func onSuggestedUserPressed(user: UserModel) {
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: user))
    }

    func onFollowButtonPressed(user: UserModel) {
        interactor.trackEvent(eventName: "DashboardView_SuggestedFollow_Press", parameters: nil, type: .analytic)
        followFlow.onButtonPressed(user: user)
    }

//    private var completedTrainingDays: Set<Date> {
//        let calendar = Calendar.current
//        let now = Date()
//        return Set(
//            interactor.workoutSessions.compactMap { session -> Date? in
//                guard session.endedAt != nil else { return nil }
//                if session.isRestDay, session.dateCreated > now { return nil }
//                return calendar.startOfDay(for: session.dateCreated)
//            }
//        )
//    }

//    var workoutStreakCount: Int {
//        let days = completedTrainingDays.sorted()
//        guard !days.isEmpty else { return 0 }
//        let calendar = Calendar.current
//        let today = calendar.startOfDay(for: Date())
//        // If the user hasn't worked out today, start from yesterday (streak is "at risk" but still alive)
//        var day = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
//        var streak = 0
//        while days.contains(day) {
//            streak += 1
//            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
//            day = prev
//        }
//        return streak
//    }
//
//    var isStreakActive: Bool {
//        let today = Calendar.current.startOfDay(for: Date())
//        return completedTrainingDays.contains(today)
//    }
//
//    var isStreakAtRisk: Bool {
//        let calendar = Calendar.current
//        let today = calendar.startOfDay(for: Date())
//        guard !completedTrainingDays.contains(today) else { return false }
//        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
//        return completedTrainingDays.contains(yesterday)
//    }
//
//    var longestStreak: Int {
//        let days = completedTrainingDays.sorted()
//        guard !days.isEmpty else { return 0 }
//        let calendar = Calendar.current
//        var longest = 1, current = 1
//        for index in 1..<days.count {
//            if calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day == 1 {
//                current += 1
//                longest = max(longest, current)
//            } else {
//                current = 1
//            }
//        }
//        return longest
//    }
//
//    var totalWorkouts: Int {
//        interactor.workoutSessions.filter { $0.endedAt != nil && !$0.isRestDay }.count
//    }
//
//    var workoutDaysThisWeek: Set<Date> {
//        let calendar = Calendar.current
//        let today = calendar.startOfDay(for: Date())
//        let weekdayIndex = calendar.component(.weekday, from: today) - 1
//        let weekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today
//        let weekDays = Set((0..<7).compactMap {
//            calendar.date(byAdding: .day, value: $0, to: weekStart)
//        })
//        return completedTrainingDays.intersection(weekDays)
//    }

    var hasActiveProgram: Bool {
        interactor.activeTrainingProgram != nil
    }

    var todaysWorkoutTemplate: WorkoutTemplateModel? {
        todaysScheduledItem?.dayPlan
    }

    var isTodayCompleted: Bool {
        todaysScheduledItem?.completedSessionId != nil
    }

    private var todaysScheduledItem: MicrocycleWorkoutTemplateModelItem? {
        guard let program = interactor.activeTrainingProgram,
              !program.workoutTemplates.isEmpty else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let weekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today

        let dayPlans = program.workoutTemplates
        let workoutIds = Set(dayPlans.filter { !$0.exercises.isEmpty }.map { $0.id })
        let dayPlanNames = Set(dayPlans.map { $0.name })
        let dayPlanById = Dictionary(uniqueKeysWithValues: dayPlans.map { ($0.id, $0) })

        let completedSessions: [(WorkoutSessionModel, WorkoutTemplateModel)] = interactor.workoutSessions
            .compactMap { session -> (WorkoutSessionModel, WorkoutTemplateModel)? in
                guard session.endedAt != nil else { return nil }
                let shouldInclude = session.trainingProgramId == program.id
                    || (session.trainingProgramId == nil && dayPlanNames.contains(session.name))
                guard shouldInclude else { return nil }
                if let id = session.workoutTemplateId, let plan = dayPlanById[id] { return (session, plan) }
                if let plan = dayPlans.first(where: { $0.name == session.name }) { return (session, plan) }
                return nil
            }
            .sorted { ($0.0.endedAt ?? .distantPast) < ($1.0.endedAt ?? .distantPast) }

        var completedInCurrentCycle = Set<String>()
        for (_, dayPlan) in completedSessions {
            guard workoutIds.contains(dayPlan.id) else { continue }
            completedInCurrentCycle.insert(dayPlan.id)
            if completedInCurrentCycle == workoutIds { completedInCurrentCycle.removeAll() }
        }

        let startIndex: Int
        if workoutIds.isEmpty {
            startIndex = 0
        } else if let first = dayPlans.firstIndex(where: { !$0.exercises.isEmpty && !completedInCurrentCycle.contains($0.id) }) {
            startIndex = first
        } else {
            startIndex = 0
        }

        let weekDates = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .map { calendar.startOfDay(for: $0) }
        let weekDateSet = Set(weekDates)

        var itemsByDay: [Date: MicrocycleWorkoutTemplateModelItem] = [:]
        for (session, dayPlan) in completedSessions {
            guard let endedAt = session.endedAt else { continue }
            if session.isRestDay, session.dateCreated > Date() { continue }
            let day = calendar.startOfDay(for: endedAt)
            guard weekDateSet.contains(day), itemsByDay[day] == nil else { continue }
            itemsByDay[day] = MicrocycleWorkoutTemplateModelItem(
                id: "\(day.timeIntervalSince1970)-\(dayPlan.id)",
                date: day,
                dayPlan: dayPlan,
                completedSessionId: session.id
            )
        }
        var nextIndex = startIndex % dayPlans.count
        for day in weekDates where itemsByDay[day] == nil {
            let dayPlan = dayPlans[nextIndex]
            itemsByDay[day] = MicrocycleWorkoutTemplateModelItem(
                id: "\(day.timeIntervalSince1970)-\(dayPlan.id)",
                date: day,
                dayPlan: dayPlan,
                completedSessionId: nil
            )
            nextIndex = (nextIndex + 1) % dayPlans.count
        }
        return itemsByDay[today]
    }

    func author(for session: WorkoutSessionModel) -> UserModel? {
        if let user = interactor.currentUser, session.authorId == user.userId {
            return user
        }
        return interactor.followingUsers.first { $0.userId == session.authorId }
    }

    init(interactor: DashboardInteractor, router: DashboardRouter) {
        self.interactor = interactor
        self.router = router
        self.followFlow = FollowFlow(interactor: interactor, router: router)
    }
    
    func onViewAppear(delegate: DashboardDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        nudgedUserIds = interactor.nudgedUserIdsToday
        loadNutrition()
    }
    
    func onViewDisappear(delegate: DashboardDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    /// The empty feed's call to action. People search lives on the Add tab, and only the tab bar can
    /// select a tab, so this asks it to — see `DeepLink.post()`.
    func onFindPeoplePressed() {
        interactor.trackEvent(
            eventName: "DashboardView_FindPeople_Press",
            parameters: nil,
            type: .analytic
        )
        DeepLink.tab(.search).post()
    }

    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }

    func onPushNotificationsPressed() {
        router.showNotificationsView()
    }
    
    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif

    func loadNotifications() async {
        // Silent: background refresh of the unread badge.
        try? await interactor.fetchActivityNotifications()
    }

    func onLogMealPressed() {
        guard let userId = interactor.currentUser?.userId else { return }
        if let meal = interactor.draftMeal {
            router.showAlert(
                title: String(localized: "Unable to add new meal"),
                subtitle: String(localized: "You already have an draft meal."),
                buttons: {
                    AnyView(
                        VStack {
                            Button("Continue editing") {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(mealLog: meal)
                                )
                            }
                            Button("Delete drafted meal", role: .destructive) {
                                try? self.interactor.deleteDraftMeal()
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(
                                        mealLog: MealLogModel(
                                            authorId: userId,
                                            dayKey: Date().dayKey,
                                            date: Date(),
                                            items: []
                                        )
                                    )
                                )
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    )
                }
            )
        } else {
            self.router.showAddMealView(
                delegate: AddMealDelegate(
                    mealLog: MealLogModel(
                        authorId: userId,
                        dayKey: Date().dayKey,
                        date: Date(),
                        items: []
                    )
                )
            )
        }
    }

    private func loadNutrition() {
        let dayKey = Date().dayKey
        // Silent: local read; a missing total shows as no data on the card.
        nutritionTotals = try? interactor.getDailyTotals(dayKey: dayKey)
        guard let userId = interactor.userId else { return }
        Task {
            // Silent: background read; the card shows no target until one loads.
            nutritionTarget = try? await interactor.getDailyTarget(for: Date(), userId: userId)
        }
    }

    // MARK: - CircleGoals

    /// The week whose Monday recap the user closed. Held here so closing it redraws at once.
    var dismissedSummaryWeekId: String? = UserDefaults.standard.string(forKey: CircleWeek.summaryDismissedWeekKey)

    // MARK: - RatingReferral

    /// Whether the invite card has been tapped or closed. Held here so closing it redraws at once.
    var inviteCardDismissed: Bool = ReviewPromptStore().inviteCardDismissed
}

extension DashboardPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: DashboardDelegate)
        case onDisappear(delegate: DashboardDelegate)
        case circleMemberPressed
        case nudgePressed

        var eventName: String {
            switch self {
            case .onAppear:                 return "DashboardView_Appear"
            case .onDisappear:              return "DashboardView_Disappear"
            case .circleMemberPressed:      return "DashboardView_CircleMember_Press"
            case .nudgePressed:             return "DashboardView_Nudge_Press"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .circleMemberPressed, .nudgePressed:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}

// MARK: - Usernames

extension DashboardPresenter {

    /// Drives the "pick a username" banner. The banner itself remembers being dismissed.
    var needsUsername: Bool {
        guard let user = interactor.currentUser else { return false }
        return user.username == nil
    }

    func onPickUsernamePressed() {
        interactor.trackEvent(eventName: "DashboardView_PickUsername_Press", parameters: [:], type: .analytic)
        router.showEditUsernameView()
    }
}

// MARK: - CircleGoals

extension DashboardPresenter {

    private var circleSessions: [WorkoutSessionModel] {
        interactor.workoutSessions + interactor.followingWorkoutSessions
    }

    /// Adds the week's ring to a strip face, and "1 to go" on the user's own on the week's last day.
    fileprivate func withWeeklyProgress(_ member: CircleMember, readerId: String, now: Date = .now) -> CircleMember {
        var member = member
        member.sessionsThisWeek = CircleWeek.sessionCount(of: member.user.userId, inWeekOf: now, sessions: circleSessions)
        member.weeklyGoal = CircleWeek.goal(for: member.user)
        member.isCurrentUser = member.user.userId == readerId
        let toGo = CircleWeek.remaining(sessions: member.sessionsThisWeek, goal: member.weeklyGoal)
        if member.isCurrentUser, toGo > 0, CircleWeek.isLastDayOfWeek(now) {
            member.sessionsToGo = toGo
        }
        return member
    }

    /// The leaderboard: the strip's people, ranked. Empty whenever the strip is.
    var circleStandings: [CircleWeek.Standing] {
        CircleWeek.standings(users: circleMembers.map(\.user), sessions: circleSessions, now: .now)
    }

    var currentUserId: String? {
        interactor.currentUser?.userId
    }

    /// The strip offers "Set goal" until the user has picked one.
    var showsWeeklyGoalPrompt: Bool {
        interactor.currentUser != nil && interactor.currentUser?.weeklySessionGoal == nil
    }

    var weeklySummary: CircleWeek.Summary? {
        let circle = circleMembers.map(\.user)
        guard let reader = interactor.currentUser, !circle.isEmpty else { return nil }
        return CircleWeek.summary(
            reader: reader,
            circle: circle,
            sessions: circleSessions,
            now: .now,
            dismissedWeekId: dismissedSummaryWeekId
        )
    }

    func onSetWeeklyGoalPressed() {
        interactor.trackEvent(eventName: "DashboardView_SetWeeklyGoal_Press", parameters: nil, type: .analytic)
        router.showWeeklyGoalView()
    }

    func onLeaderboardRowPressed(_ standing: CircleWeek.Standing) {
        interactor.trackEvent(eventName: "DashboardView_LeaderboardRow_Press", parameters: nil, type: .analytic)
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: standing.user))
    }

    func onWeeklySummaryDismissed() {
        guard let weekId = weeklySummary?.weekId else { return }
        interactor.trackEvent(eventName: "DashboardView_WeeklySummary_Dismiss", parameters: nil, type: .analytic)
        dismissedSummaryWeekId = weekId
        UserDefaults.standard.set(weekId, forKey: CircleWeek.summaryDismissedWeekKey)
    }
}

// MARK: - Challenges

extension DashboardPresenter {

    struct ChallengeCard: Identifiable {
        let challenge: ChallengeModel
        let daysLeft: Int
        let mySessions: Int
        let topThree: [ChallengeStandings.Entry]

        var id: String { challenge.id }
    }

    /// Running challenges first, soonest to end first; ended ones are left to the detail screen.
    var challengeCards: [ChallengeCard] {
        let now = Date()
        var users: [String: UserModel] = [:]
        for user in interactor.followingUsers { users[user.userId] = user }
        if let reader = interactor.currentUser { users[reader.userId] = reader }
        let readerId = interactor.currentUser?.userId

        return interactor.challenges
            .filter { $0.endsAt > now }
            .map { challenge in
                let progress = interactor.challengeProgress(challengeId: challenge.id)
                return ChallengeCard(
                    challenge: challenge,
                    daysLeft: challenge.daysLeft(from: now),
                    mySessions: readerId.flatMap { progress[$0] } ?? 0,
                    topThree: Array(ChallengeStandings.entries(for: challenge, progress: progress, users: users).prefix(3))
                )
            }
    }

    /// Shown once there is a circle to challenge, or a challenge someone else started.
    var showsChallengesSection: Bool {
        !challengeCards.isEmpty || !circleMembers.isEmpty
    }

    func loadChallenges() async {
        // Silent: background refresh; the section keeps what it had.
        try? await interactor.refreshChallenges()
    }

    func onChallengePressed(_ card: ChallengeCard) {
        interactor.trackEvent(eventName: "DashboardView_Challenge_Press", parameters: nil, type: .analytic)
        router.showChallengeDetailView(delegate: ChallengeDetailDelegate(challenge: card.challenge))
    }

    func onCreateChallengePressed() {
        interactor.trackEvent(eventName: "DashboardView_CreateChallenge_Press", parameters: nil, type: .analytic)
        router.showCreateChallengeView()
    }
}

// MARK: - Invites

extension DashboardPresenter {
    /// A `compound://join/<code>` link, relayed by the tab bar once it has selected this tab.
    func onAcceptInviteNotificationReceived(_ notification: Notification) {
        guard let code = notification.userInfo?["code"] as? String else { return }
        let flow = InviteAcceptFlow(interactor: interactor, router: router)
        Task { await flow.accept(code: code) }
    }
}

// MARK: - WeeklyReview

extension DashboardPresenter {
    /// The way in to last week's review, on the first day of the week only.
    var showsWeeklyReviewCard: Bool {
        interactor.currentUser != nil && CircleWeek.isFirstDayOfWeek(.now)
    }

    func onWeeklyReviewPressed() {
        interactor.trackEvent(eventName: "DashboardView_WeeklyReview_Press", parameters: nil, type: .analytic)
        router.showWeeklyReviewView()
    }
}

// MARK: - RatingReferral

extension DashboardPresenter {
    /// The one-time invite card, from the fifth finished workout until it is tapped or dismissed.
    var showsInviteCard: Bool {
        interactor.currentUser != nil && ReviewPromptPolicy.showsInviteCard(
            completedSessions: ReviewPromptStore().completedSessions,
            inviteCardDismissed: inviteCardDismissed
        )
    }

    func onInviteCardPressed() {
        interactor.trackEvent(eventName: "DashboardView_InviteCard_Press", parameters: nil, type: .analytic)
        dismissInviteCard()
        Task { await InviteShareFlow(interactor: interactor, router: router).share() }
    }

    func onInviteCardDismissed() {
        interactor.trackEvent(eventName: "DashboardView_InviteCard_Dismiss", parameters: nil, type: .analytic)
        dismissInviteCard()
    }

    private func dismissInviteCard() {
        ReviewPromptStore().inviteCardDismissed = true
        inviteCardDismissed = true
    }
}

// MARK: - FeedLoading

extension DashboardPresenter {
    /// A spinner rather than "No Activity Yet" until the following feed has answered once: the
    /// user's own sessions arrive first, so an empty feed before then only means "not loaded".
    var isFeedLoading: Bool {
        feedSessions.isEmpty && !interactor.hasLoadedFollowingSessions
    }
}
