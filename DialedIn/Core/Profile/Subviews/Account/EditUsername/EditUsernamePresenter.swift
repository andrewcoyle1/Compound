import SwiftUI

@Observable
@MainActor
class EditUsernamePresenter {

    enum Status: Equatable {
        /// Nothing typed.
        case idle
        /// The handle the user already has.
        case current
        case invalid(String)
        case checking
        case available
        case taken
        /// The availability read failed, so nothing is known either way.
        case failed
    }

    private let interactor: EditUsernameInteractor
    private let router: EditUsernameRouter
    private let debounce: Duration
    private var checkTask: Task<Void, Never>?

    var text: String
    private(set) var status: Status
    private(set) var isSaving = false

    var canSave: Bool {
        status == .available && !isSaving
    }

    /// `debounce` is injectable so tests can pass `.zero`.
    init(interactor: EditUsernameInteractor, router: EditUsernameRouter, debounce: Duration = .milliseconds(300)) {
        self.interactor = interactor
        self.router = router
        self.debounce = debounce
        let current = interactor.currentUser?.username
        self.text = current ?? ""
        self.status = current == nil ? .idle : .current
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    /// Validates at once, then checks availability once typing has paused for `debounce`.
    func onTextChanged() {
        checkTask?.cancel()
        let handle = Username.normalised(text)
        // Stored lowercase, so the field shows what will be stored. Setting it re-enters here with
        // the same value, which is harmless.
        if text != handle { text = handle }

        if handle.isEmpty {
            status = .idle
            return
        }
        if handle == interactor.currentUser?.username {
            status = .current
            return
        }
        if let message = Username.validate(handle).message {
            status = .invalid(message)
            return
        }

        // Offline, the read answers from the cache, which can call a taken handle available.
        guard !interactor.isOffline else {
            status = .failed
            return
        }
        status = .checking
        checkTask = Task { [debounce, interactor] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            // Not silent: nil maps to `.failed`, which the field shows inline.
            let available = try? await interactor.isUsernameAvailable(handle)
            guard !Task.isCancelled else { return }
            switch available {
            case true?: status = .available
            case false?: status = .taken
            case nil: status = .failed
            }
        }
    }

    func onSavePressed() async {
        guard canSave, interactor.ensureOnline(or: router) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await interactor.claimUsername(text)
            interactor.trackEvent(event: Event.saveSuccess)
            router.dismissScreen()
        } catch UsernameError.taken {
            // Someone reserved it between the check and the save.
            status = .taken
            interactor.trackEvent(event: Event.saveFail(error: UsernameError.taken))
        } catch {
            interactor.trackEvent(event: Event.saveFail(error: error))
            router.showSimpleAlert(title: String(localized: "Unable to save"), subtitle: String(localized: "Please check your connection and try again."))
        }
    }
}

extension EditUsernamePresenter {

    enum Event: LoggableEvent {
        case onAppear
        case saveSuccess
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:    return "EditUsernameView_Appear"
            case .saveSuccess: return "EditUsernameView_Save_Success"
            case .saveFail:    return "EditUsernameView_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default: return .analytic
            }
        }
    }
}
