//
//  CoachChatsView.swift
//  Compound
//
//  The coach's saved chats, and the permission behind them. Reached from the coach's menu and
//  from Settings; withdrawing the permission deletes every chat.
//

import SwiftUI

struct CoachChatsDelegate {
    /// What a chat opened from here is about, when the list was opened from the coach.
    var context: CoachContext = .today
}

@Observable
@MainActor
class CoachChatsPresenter {

    let interactor: CoachInteractor
    let router: CoachRouter
    let delegate: CoachChatsDelegate
    private(set) var isWithdrawing = false

    init(interactor: CoachInteractor, router: CoachRouter, delegate: CoachChatsDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }

    var chats: [CoachChat] { interactor.coachChats }
    var hasConsented: Bool { interactor.coachHasConsented }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onChatPressed(_ chat: CoachChat) {
        interactor.trackEvent(event: Event.chatPressed)
        let kind = chat.contextKind.flatMap(CoachContext.Kind.init(rawValue:)) ?? delegate.context.kind
        router.showCoachChatView(delegate: CoachDelegate(context: CoachContext(kind: kind), chatId: chat.id, showsCloseButton: false))
    }

    func onNewChatPressed() {
        interactor.trackEvent(event: Event.newChatPressed)
        router.showCoachChatView(delegate: CoachDelegate(context: delegate.context, showsCloseButton: false))
    }

    func onDelete(_ chat: CoachChat) {
        interactor.trackEvent(event: Event.deleteStart)
        Task {
            do {
                try await interactor.coachDeleteChat(id: chat.id)
                interactor.trackEvent(event: Event.deleteSuccess)
            } catch {
                interactor.trackEvent(event: Event.deleteFail(error: error))
                router.showFailure(String(localized: "Unable to Delete Chat"), error: error)
            }
        }
    }

    func onWithdrawPressed() {
        router.showConfirmationDialog(
            title: String(localized: "Withdraw Permission?"),
            subtitle: String(localized: "The coach stops reading your data and every chat is deleted."),
            buttons: {
                AnyView(VStack {
                    Button("Withdraw and Delete Chats", role: .destructive) { self.onWithdrawConfirmed() }
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }

    func onWithdrawConfirmed() {
        isWithdrawing = true
        interactor.trackEvent(event: Event.withdrawStart)
        Task {
            defer { isWithdrawing = false }
            do {
                try await interactor.coachWithdrawConsent()
                interactor.trackEvent(event: Event.withdrawSuccess)
                interactor.playHaptic(option: .success)
            } catch {
                interactor.trackEvent(event: Event.withdrawFail(error: error))
                router.showFailure(String(localized: "Unable to Withdraw Permission"), error: error)
            }
        }
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case chatPressed
        case newChatPressed
        case deleteStart
        case deleteSuccess
        case deleteFail(error: Error)
        case withdrawStart
        case withdrawSuccess
        case withdrawFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "CoachChatsView_Appear"
            case .onDisappear: return "CoachChatsView_Disappear"
            case .chatPressed: return "CoachChatsView_Chat_Press"
            case .newChatPressed: return "CoachChatsView_NewChat_Press"
            case .deleteStart: return "CoachChatsView_DeleteChat_Start"
            case .deleteSuccess: return "CoachChatsView_DeleteChat_Success"
            case .deleteFail: return "CoachChatsView_DeleteChat_Fail"
            case .withdrawStart: return "CoachChatsView_Withdraw_Start"
            case .withdrawSuccess: return "CoachChatsView_Withdraw_Success"
            case .withdrawFail: return "CoachChatsView_Withdraw_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteFail(let error), .withdrawFail(let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .withdrawFail: return .severe
            case .deleteFail: return .warning
            default: return .analytic
            }
        }
    }
}

struct CoachChatsView: View {

    @State var presenter: CoachChatsPresenter

    var body: some View {
        List {
            Section {
                if presenter.chats.isEmpty {
                    ContentUnavailableView("No Chats Yet", systemImage: Symbol.coach, description: Text("Your conversations with the coach appear here."))
                }
                ForEach(presenter.chats) { chat in
                    ListRowButton(
                        title: chat.title,
                        subtitle: chat.updatedAt.formatted(.relative(presentation: .named)),
                        systemImage: Symbol.coach
                    ) {
                        presenter.onChatPressed(chat)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: Symbol.delete, role: .destructive) {
                            presenter.onDelete(chat)
                        }
                    }
                }
            }
            if presenter.hasConsented {
                Section {
                    Button("Withdraw Permission and Delete Chats", role: .destructive) {
                        presenter.onWithdrawPressed()
                    }
                    .disabled(presenter.isWithdrawing)
                } header: {
                    Text("Data Sharing")
                } footer: {
                    Text("The coach reads your workouts, nutrition, body data and steps to answer, through Google's Gemini model in the EU. It never reads progress photos, people you follow, or Strava activities.")
                }
            }
        }
        .navigationTitle("Coach Chats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Chat", systemImage: Symbol.add) { presenter.onNewChatPressed() }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }
}

extension CoreBuilder {
    func coachChatsView(router: AnyRouter, delegate: CoachChatsDelegate) -> some View {
        CoachChatsView(presenter: CoachChatsPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self),
            delegate: delegate
        ))
    }
}

extension CoreRouter {
    func showCoachChatsView(delegate: CoachChatsDelegate) {
        router.showScreen(.push) { router in
            builder.coachChatsView(router: router, delegate: delegate)
        }
    }
}
