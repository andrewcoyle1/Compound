//
//  CreateChallengePresenter.swift
//  DialedIn
//

import SwiftUI

@Observable
@MainActor
class CreateChallengePresenter {
    private let interactor: CreateChallengeInteractor
    private let router: CreateChallengeRouter

    var title: String = ""
    var targetSessions: Int = 8
    var durationDays: Int = 14
    private(set) var selectedIds: Set<String> = []
    private(set) var isSaving: Bool = false

    init(interactor: CreateChallengeInteractor, router: CreateChallengeRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// Mutuals only, as for sharing: a challenge lands in the other person's Dashboard, so they
    /// must follow the owner back. Anyone the owner has blocked is left out.
    var candidates: [UserModel] {
        guard let reader = interactor.currentUser else { return [] }
        return interactor.followingUsers.filter { user in
            user.userId != reader.userId
                && !reader.hasBlocked(user.userId)
                && (user.followingIds ?? []).contains(reader.userId)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Why Create is disabled, shown under the form; nil when it is ready.
    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Give the challenge a name." }
        if trimmedTitle.count > ChallengeModel.titleMaxLength {
            return String(localized: "Keep the name under \(ChallengeModel.titleMaxLength) characters.")
        }
        if !ChallengeModel.targetRange.contains(targetSessions) {
            return String(localized: "Pick a target between \(String(describing: ChallengeModel.targetRange.lowerBound)) and \(String(describing: ChallengeModel.targetRange.upperBound)) sessions.")
        }
        if !ChallengeModel.durations.contains(durationDays) { return "Pick a duration." }
        if selectedMemberIds.isEmpty { return "Invite at least one person." }
        return nil
    }

    var canCreate: Bool {
        validationMessage == nil && !isSaving
    }

    /// Selected ids still in the candidate list, in its order.
    private var selectedMemberIds: [String] {
        candidates.map(\.userId).filter(selectedIds.contains)
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func isSelected(_ user: UserModel) -> Bool {
        selectedIds.contains(user.userId)
    }

    func onCandidatePressed(_ user: UserModel) {
        if selectedIds.remove(user.userId) == nil {
            selectedIds.insert(user.userId)
        }
    }

    func onCreatePressed() {
        guard canCreate else { return }
        let memberIds = selectedMemberIds
        isSaving = true
        interactor.trackEvent(event: Event.createStart(target: targetSessions, days: durationDays, members: memberIds.count))
        Task {
            do {
                try await interactor.createChallenge(
                    title: trimmedTitle,
                    targetSessions: targetSessions,
                    durationDays: durationDays,
                    memberIds: memberIds
                )
                interactor.trackEvent(event: Event.createSuccess)
                router.dismissScreen()
            } catch {
                isSaving = false
                interactor.trackEvent(event: Event.createFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to create challenge"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onCancelPressed() {
        router.dismissScreen()
    }
}

extension CreateChallengePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case createStart(target: Int, days: Int, members: Int)
        case createSuccess
        case createFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:         return "CreateChallengeView_Appear"
            case .createStart:      return "CreateChallengeView_Create_Start"
            case .createSuccess:    return "CreateChallengeView_Create_Success"
            case .createFail:       return "CreateChallengeView_Create_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .createStart(let target, let days, let members):
                return ["target_sessions": target, "duration_days": days, "member_count": members]
            case .createFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .createFail: return .severe
            default: return .analytic
            }
        }
    }
}
