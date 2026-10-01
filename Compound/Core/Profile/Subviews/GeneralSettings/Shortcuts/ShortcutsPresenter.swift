import SwiftUI

@Observable
@MainActor
class ShortcutsPresenter {

    private let interactor: ShortcutsInteractor
    private let router: ShortcutsRouter

    /// Snapshot-and-save, the idiom every other settings screen here uses. No Save button — the one
    /// that used to sit in this screen's toolbar had an empty action.
    private var settings: ShortcutSettings

    init(interactor: ShortcutsInteractor, router: ShortcutsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.shortcutSettings
    }

    /// In the order they appear on the Search tab.
    var quickActions: [QuickAction] {
        settings.quickActions
    }

    /// Everything not currently shown, in declaration order so the list is stable as actions are
    /// added and removed.
    var availableActions: [QuickAction] {
        let shown = Set(quickActions)
        return QuickAction.allCases.filter { !shown.contains($0) }
    }

    func onAddPressed(_ action: QuickAction) {
        var actions = quickActions
        guard !actions.contains(action) else { return }
        actions.append(action)
        apply(actions, event: .actionAdded(action: action))
    }

    func onRemove(at offsets: IndexSet) {
        var actions = quickActions
        let removed = offsets.compactMap { actions.indices.contains($0) ? actions[$0] : nil }
        actions.remove(atOffsets: offsets)
        apply(actions, event: .actionsRemoved(count: removed.count))
    }

    func onMove(from source: IndexSet, to destination: Int) {
        var actions = quickActions
        actions.move(fromOffsets: source, toOffset: destination)
        apply(actions, event: .actionsReordered)
    }

    func onRestoreDefaultsPressed() {
        apply(QuickAction.defaultActions, event: .defaultsRestored)
    }

    var isShowingDefaults: Bool {
        quickActions == QuickAction.defaultActions
    }

    private func apply(_ actions: [QuickAction], event: Event) {
        settings.setQuickActions(actions)
        interactor.trackEvent(event: event)
        let settings = settings
        Task {
            do {
                try await interactor.saveShortcutSettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// Re-read rather than trusting the snapshot taken at init: `apply(_:event:)` writes the whole
    /// `ShortcutSettings` document, so a copy taken when this screen was first pushed would revert
    /// a change made on another device while it sat there.
    func onViewAppear() {
        settings = interactor.shortcutSettings
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
}

extension ShortcutsPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case actionAdded(action: QuickAction)
        case actionsRemoved(count: Int)
        case actionsReordered
        case defaultsRestored
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "ShortcutsView_Save_Fail"
            case .onAppear:         return "ShortcutsView_Appear"
            case .onDisappear:      return "ShortcutsView_Disappear"
            case .actionAdded:      return "ShortcutsView_Action_Added"
            case .actionsRemoved:   return "ShortcutsView_Actions_Removed"
            case .actionsReordered: return "ShortcutsView_Actions_Reordered"
            case .defaultsRestored: return "ShortcutsView_Defaults_Restored"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .actionAdded(action: let action):
                return ["action": action.rawValue]
            case .actionsRemoved(count: let count):
                return ["count": count]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default:
                return .analytic
            }
        }
    }
}
