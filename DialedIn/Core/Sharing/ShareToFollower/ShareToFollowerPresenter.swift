//
//  ShareToFollowerPresenter.swift
//  DialedIn
//

import SwiftUI

@Observable
@MainActor
class ShareToFollowerPresenter {
    private let interactor: ShareToFollowerInteractor
    private let router: ShareToFollowerRouter
    let delegate: ShareToFollowerDelegate

    private(set) var selectedIds: Set<String> = []
    private(set) var isSending: Bool = false

    /// Mutuals only: someone who does not follow the user back has not asked to hear from them.
    /// Anyone the user has blocked is left out too.
    var recipients: [UserModel] {
        guard let reader = interactor.currentUser else { return [] }
        return interactor.followingUsers.filter { user in
            user.userId != reader.userId
                && !reader.hasBlocked(user.userId)
                && (user.followingIds ?? []).contains(reader.userId)
        }
    }

    var canSend: Bool {
        !selectedIds.isEmpty && !isSending
    }

    init(interactor: ShareToFollowerInteractor, router: ShareToFollowerRouter, delegate: ShareToFollowerDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func isSelected(_ user: UserModel) -> Bool {
        selectedIds.contains(user.userId)
    }

    func onRecipientPressed(_ user: UserModel) {
        if selectedIds.remove(user.userId) == nil {
            selectedIds.insert(user.userId)
        }
    }

    func onSendPressed() {
        guard canSend, interactor.ensureOnline(or: router) else { return }
        let ids = recipients.map(\.userId).filter(selectedIds.contains)
        isSending = true
        interactor.trackEvent(event: Event.sendStart(kind: delegate.payload.kind, count: ids.count))
        Task {
            do {
                try await interactor.sendShare(delegate.payload, to: ids)
                interactor.trackEvent(event: Event.sendSuccess)
                router.dismissScreen()
            } catch {
                isSending = false
                interactor.trackEvent(event: Event.sendFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to share"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onCancelPressed() {
        router.dismissScreen()
    }
}

extension ShareToFollowerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case sendStart(kind: String, count: Int)
        case sendSuccess
        case sendFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:     return "ShareToFollowerView_Appear"
            case .sendStart:    return "ShareToFollowerView_Send_Start"
            case .sendSuccess:  return "ShareToFollowerView_Send_Success"
            case .sendFail:     return "ShareToFollowerView_Send_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .sendStart(let kind, let count):
                return ["kind": kind, "recipient_count": count]
            case .sendFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .sendFail: return .severe
            default: return .analytic
            }
        }
    }
}
