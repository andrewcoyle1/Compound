import SwiftUI

@Observable
@MainActor
class SocialProfilePresenter {

    private let interactor: SocialProfileInteractor
    private let router: SocialProfileRouter
    let reportFlow: ReportFlow
    private let followFlow: FollowFlow

    private var profileUser: UserModel?
    var followers: [UserModel] = []
    private var fetchedSessions: [WorkoutSessionModel] = []

    var followersCount: Int { followers.count }

    var followingCount: Int {
        profileUser?.followingIds?.count ?? 0
    }

    /// Follow, Following or Requested, read live off the reader's own document and sent requests so
    /// the button flips when the write lands rather than from a local copy.
    var followState: FollowState {
        guard let profileUser else { return .follow }
        return followFlow.state(for: profileUser)
    }

    var isFollowing: Bool {
        followState == .following
    }

    /// Instagram's "Follows you": the profile's own following list names the reader.
    var followsYou: Bool {
        guard let profileUser, !isOwnProfile, let readerId = interactor.currentUser?.userId else { return false }
        return profileUser.followingIds?.contains(readerId) ?? false
    }

    /// The reader's own profile has no follow button.
    var isOwnProfile: Bool {
        profileUser?.userId == interactor.currentUser?.userId
    }

    /// A private profile shows its lists, consistency and sessions only to its owner and its
    /// followers — and following a private profile needs its owner to accept a request first.
    /// Everyone else gets the header, the counts and a lock message.
    var isLocked: Bool {
        guard let profileUser, profileUser.isPrivate == true, !isOwnProfile else { return false }
        return !isFollowing
    }

    /// Whether the reader has blocked this profile, read live so the menu flips when the write lands.
    var isBlocked: Bool {
        guard let profileUser else { return false }
        return interactor.currentUser?.hasBlocked(profileUser.userId) ?? false
    }

    /// Nobody follows an account they have blocked, or themselves.
    var showsFollowButton: Bool {
        !isOwnProfile && !isBlocked
    }

    private var displayName: String {
        profileUser?.fullNameCalculated ?? "User"
    }

    var blockMenuTitle: String {
        isBlocked ? String(localized: "Unblock") : String(localized: "Block \(displayName)")
    }

    var mutualFollowers: [UserModel] {
        guard let profileFollowingIds = profileUser?.followingIds else { return [] }
        return interactor.followingUsers.filter { profileFollowingIds.contains($0.userId) }
    }

    /// Finished, non-rest sessions, newest first. The reader's own come from the local collection
    /// rather than a fetch; a locked profile shows none.
    var sessions: [WorkoutSessionModel] {
        guard !isLocked else { return [] }
        return (isOwnProfile ? interactor.workoutSessions : fetchedSessions)
            .filter { $0.endedAt != nil && !$0.isRestDay }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    /// The streak stamped on the author's most recent session that carries one, from two days on.
    /// The reader cannot see anyone else's streak directly, so this is as fresh as their last
    /// finished workout.
    var latestStreak: Int? {
        guard let count = sessions.first(where: { $0.streakCount != nil })?.streakCount, count > 1 else { return nil }
        return count
    }

    /// One entry per calendar day with a finished session, for the consistency grid.
    var trainingDays: Set<Date> {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.dateCreated) })
    }

    /// The grid's data: a point per training day in the last twelve weeks.
    var consistencySeries: TimeSeries {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: .now) ?? .distantPast
        let days = trainingDays.filter { $0 >= cutoff }.sorted()
        return TimeSeries(
            name: "Training Days",
            data: days.map { TimeSeriesDatapoint(id: $0.ISO8601Format(), date: $0, value: 1) }
        )
    }

    /// Only the reader's own program resolves without fetching someone else's programs, which
    /// live under their own user document.
    var programName: String? {
        isOwnProfile ? interactor.activeTrainingProgram?.name : nil
    }

    init(interactor: SocialProfileInteractor, router: SocialProfileRouter) {
        self.interactor = interactor
        self.router = router
        self.reportFlow = ReportFlow(interactor: interactor, router: router)
        self.followFlow = FollowFlow(interactor: interactor, router: router)
    }

    func onViewAppear(delegate: SocialProfileDelegate) {
        profileUser = delegate.user
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        loadFollowers(userId: delegate.user.userId)
        if !isLocked, !isOwnProfile {
            loadSessions(userId: delegate.user.userId)
        }
    }

    private func loadSessions(userId: String) {
        isLoadingSessions = true
        Task {
            defer { isLoadingSessions = false }
            do {
                fetchedSessions = try await interactor.fetchWorkoutSessions(authorId: userId, limit: 30)
            } catch {
                // Silent — the empty state stands in for sessions that could not be read.
            }
        }
    }

    private func loadFollowers(userId: String) {
        Task {
            do {
                followers = try await interactor.fetchFollowers(userId: userId)
            } catch {
                // Silent — followers stay empty in mock mode
            }
        }
    }

    func onFollowersPressed() {
        guard !isLocked else { return }
        let delegate = FollowersListDelegate(followers: followers, canRemoveFollowers: isOwnProfile)
        router.showFollowersList(delegate: delegate)
    }

    /// The "See all" beside the overlapping avatars was a plain `Text` — styled like a link, wired
    /// to nothing. It opens the same list screen the followers count does.
    func onMutualFollowersPressed() {
        let delegate = FollowersListDelegate(
            followers: mutualFollowers,
            title: "People You Both Follow"
        )
        router.showFollowersList(delegate: delegate)
    }

    /// The profile's following list, fetched by id when asked for. Locked like the followers list.
    func onFollowingPressed() {
        guard let profileUser, !isLocked else { return }
        Task {
            do {
                let users = try await interactor.fetchUsers(userIds: profileUser.followingIds ?? [])
                router.showFollowersList(delegate: FollowersListDelegate(followers: users, title: String(localized: "Following")))
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to load following"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// Follows a public profile, requests a private one, or takes back whichever is in place.
    func onFollowButtonPressed() {
        guard let profileUser else { return }
        switch followState {
        case .follow: interactor.trackEvent(event: Event.followPressed)
        case .following: interactor.trackEvent(event: Event.unfollowPressed)
        case .requested: interactor.trackEvent(event: Event.cancelRequestPressed)
        }
        followFlow.onButtonPressed(user: profileUser)
    }

    func onBlockMenuPressed() {
        if isBlocked {
            onUnblockPressed()
        } else {
            onBlockPressed()
        }
    }

    /// Blocking is asked about first: it also unfollows, and hides the person everywhere.
    func onBlockPressed() {
        guard profileUser != nil, !isOwnProfile else { return }
        router.showAlert(
            title: String(localized: "Block \(displayName)?"),
            subtitle: String(localized: "They will be hidden from your feed, comments, search and notifications, and you will stop following them."),
            buttons: {
                AnyView(
                    Group {
                        Button("Block", role: .destructive) {
                            self.onBlockConfirmed()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onBlockConfirmed() {
        guard let profileUser else { return }
        interactor.trackEvent(event: Event.blockConfirmed)
        Task {
            do {
                try await interactor.blockUser(userId: profileUser.userId)
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to block user"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onUnblockPressed() {
        guard let profileUser else { return }
        interactor.trackEvent(event: Event.unblockPressed)
        Task {
            do {
                try await interactor.unblockUser(userId: profileUser.userId)
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to unblock user"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onReportPressed() {
        guard let profileUser, !isOwnProfile else { return }
        reportFlow.start(ReportedContent(type: .user, id: profileUser.userId, authorUserId: profileUser.userId, noun: "profile"))
    }

    func onViewDisappear(delegate: SocialProfileDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Empty and loading states

    /// Another user's sessions are fetched on appear; until they land the section shows a spinner
    /// rather than "No workouts yet".
    private(set) var isLoadingSessions = false
}

extension SocialProfilePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: SocialProfileDelegate)
        case onDisappear(delegate: SocialProfileDelegate)
        case followPressed
        case unfollowPressed
        case cancelRequestPressed
        case blockConfirmed
        case unblockPressed

        var eventName: String {
            switch self {
            case .onAppear:                 return "SocialProfileView_Appear"
            case .onDisappear:              return "SocialProfileView_Disappear"
            case .followPressed:            return "SocialProfileView_Follow_Pressed"
            case .unfollowPressed:          return "SocialProfileView_Unfollow_Pressed"
            case .cancelRequestPressed:     return "SocialProfileView_CancelRequest_Pressed"
            case .blockConfirmed:           return "SocialProfileView_Block_Confirmed"
            case .unblockPressed:           return "SocialProfileView_Unblock_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
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

// MARK: - CircleGoals

extension SocialProfilePresenter {

    /// The owner's own weekly goal, read live so it changes when the sheet saves. Nil on anyone
    /// else's profile.
    var weeklyGoalText: String? {
        guard isOwnProfile, let user = interactor.currentUser else { return nil }
        let goal = CircleWeek.goal(for: user)
        return user.weeklySessionGoal == nil
            ? "Set a weekly goal"
            : "Goal: \(goal) \(goal == 1 ? String(localized: "session") : String(localized: "sessions")) a week"
    }

    func onWeeklyGoalPressed() {
        guard isOwnProfile else { return }
        interactor.trackEvent(eventName: "SocialProfileView_WeeklyGoal_Pressed", parameters: nil, type: .analytic)
        router.showWeeklyGoalView()
    }
}
