//
//  ChallengeDetailPresenter.swift
//  DialedIn
//

import SwiftUI

@Observable
@MainActor
class ChallengeDetailPresenter {
    private let interactor: ChallengeDetailInteractor
    private let router: ChallengeDetailRouter
    private let delegate: ChallengeDetailDelegate

    /// Members the reader does not follow, fetched on appear so the standings can name them.
    private(set) var fetchedUsers: [String: UserModel] = [:]

    init(interactor: ChallengeDetailInteractor, router: ChallengeDetailRouter, delegate: ChallengeDetailDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }

    /// The manager's copy once it has one — it carries member edits — else the one opened with.
    var challenge: ChallengeModel {
        interactor.challenges.first { $0.id == delegate.challenge.id } ?? delegate.challenge
    }

    var currentUserId: String? {
        interactor.currentUser?.userId
    }

    private var knownUsers: [String: UserModel] {
        var users = fetchedUsers
        for user in interactor.followingUsers { users[user.userId] = user }
        if let reader = interactor.currentUser { users[reader.userId] = reader }
        return users
    }

    var standings: [ChallengeStandings.Entry] {
        ChallengeStandings.entries(
            for: challenge,
            progress: interactor.challengeProgress(challengeId: challenge.id),
            users: knownUsers
        )
    }

    var mySessions: Int {
        guard let currentUserId else { return 0 }
        return interactor.challengeProgress(challengeId: challenge.id)[currentUserId] ?? 0
    }

    var myRingProgress: Double {
        ChallengeStandings.ringProgress(sessions: mySessions, target: challenge.targetSessions)
    }

    var daysLeftText: String {
        let days = challenge.daysLeft(from: .now)
        switch days {
        case 0: return String(localized: "Ended")
        case 1: return String(localized: "1 day left")
        default: return String(localized: "\(days) days left")
        }
    }

    var isMember: Bool {
        guard let currentUserId else { return false }
        return challenge.memberIds.contains(currentUserId)
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func loadStandings() async {
        // Silent: the standings already on screen stay put if the refresh fails.
        try? await interactor.refreshChallengeProgress(challengeId: challenge.id)
        let missing = challenge.memberIds.filter { knownUsers[$0] == nil }
        for userId in missing {
            // Silent: an unfetchable member stays "Member".
            if let user = try? await interactor.getUser(userId: userId) {
                fetchedUsers[userId] = user
            }
        }
    }

    func onMemberPressed(_ entry: ChallengeStandings.Entry) {
        guard let user = knownUsers[entry.userId] else { return }
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: user))
    }

    func onLeavePressed() {
        let title = challenge.title
        router.showAlert(
            title: String(localized: "Leave \(title)?"),
            subtitle: String(localized: "Your progress will no longer count."),
            buttons: {
                AnyView(VStack {
                    Button("Leave", role: .destructive) { self.leave() }
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }

    func leave() {
        interactor.trackEvent(event: Event.leaveStart)
        Task {
            do {
                try await interactor.leaveChallenge(id: challenge.id)
                interactor.trackEvent(event: Event.leaveSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.leaveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to leave"), subtitle: String(localized: "Please try again."))
            }
        }
    }
}

extension ChallengeDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case leaveStart
        case leaveSuccess
        case leaveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:     return "ChallengeDetailView_Appear"
            case .leaveStart:   return "ChallengeDetailView_Leave_Start"
            case .leaveSuccess: return "ChallengeDetailView_Leave_Success"
            case .leaveFail:    return "ChallengeDetailView_Leave_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .leaveFail(let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .leaveFail: return .severe
            default: return .analytic
            }
        }
    }
}
