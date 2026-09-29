import SwiftUI

@Observable
@MainActor
class TimelineActionsPresenter {
    
    private let interactor: TimelineActionsInteractor
    private let router: TimelineActionsRouter

    private var settings: FoodLogSettings

    /// Set when Copy Day is chosen, which presents the destination picker.
    var isChoosingCopyDestination: Bool = false
    var copyDestination: Date = Date()

    init(interactor: TimelineActionsInteractor, router: TimelineActionsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.foodLogSettings
    }

    var hideFoodDetails: Bool {
        get { settings.hideFoodDetails }
        set { settings.hideFoodDetails = newValue; save() }
    }

    var hideEmptyHours: Bool {
        get { settings.hideEmptyHours }
        set { settings.hideEmptyHours = newValue; save() }
    }

    private func save() {
        Task {
            do {
                try await interactor.saveFoodLogSettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onCopyDayPressed(delegate: TimelineActionsDelegate) {
        copyDestination = Calendar.current.date(byAdding: .day, value: 1, to: delegate.date) ?? delegate.date
        isChoosingCopyDestination = true
    }

    /// Re-logs the day's meals against the chosen date. Each copy gets a fresh `mealId` so it is a
    /// new entry rather than a move, and keeps its time of day.
    func onCopyDayConfirmed(delegate: TimelineActionsDelegate) {
        guard let authorId = interactor.currentUser?.userId else { return }
        // Silent: local read; a failure falls through to the "Nothing to copy" alert below.
        let meals = (try? interactor.getMeals(for: delegate.date.dayKey)) ?? []
        guard !meals.isEmpty else {
            isChoosingCopyDestination = false
            router.showSimpleAlert(title: String(localized: "Nothing to copy"), subtitle: String(localized: "This day has no meals logged."))
            return
        }

        let destination = copyDestination
        interactor.trackEvent(event: Event.onCopyDay(count: meals.count))
        Task {
            do {
                for meal in meals {
                    try await interactor.saveMeal(copy(of: meal, to: destination, authorId: authorId))
                }
                isChoosingCopyDestination = false
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.onActionFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to copy day"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    private func copy(of meal: MealLogModel, to destination: Date, authorId: String) -> MealLogModel {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: meal.date)
        let date = calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: destination
        ) ?? destination

        return MealLogModel(
            authorId: authorId,
            dayKey: date.dayKey,
            date: date,
            items: meal.items,
            notes: meal.notes
        )
    }

    func onClearDayPressed(delegate: TimelineActionsDelegate) {
        // Silent: local read; a failure falls through to the empty-day guard below.
        let meals = (try? interactor.getMeals(for: delegate.date.dayKey)) ?? []
        guard !meals.isEmpty else {
            router.showSimpleAlert(title: String(localized: "Nothing to clear"), subtitle: String(localized: "This day has no meals logged."))
            return
        }

        // Destructive and not undoable, so it is confirmed before anything is deleted.
        let noun = meals.count == 1 ? String(localized: "meal") : String(localized: "meals")
        router.showAlert(
            title: String(localized: "Clear this day?"),
            subtitle: String(localized: "\(String(describing: meals.count)) logged \(noun) will be deleted. This cannot be undone."),
            buttons: {
                AnyView(
                    Group {
                        Button("Clear Day", role: .destructive) {
                            self.clearDay(meals: meals)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func clearDay(meals: [MealLogModel]) {
        interactor.trackEvent(event: Event.onClearDay(count: meals.count))
        Task {
            do {
                for meal in meals {
                    try await interactor.deleteMealAndSync(
                        id: meal.mealId,
                        dayKey: meal.dayKey,
                        authorId: meal.authorId
                    )
                }
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.onActionFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to clear day"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `FoodLogSettings` document, so a stale copy would revert whatever the Food Log settings
    /// screens — or the favourite food and recipe ids written from this same tab — saved in the
    /// meantime.
    func onViewAppear(delegate: TimelineActionsDelegate) {
        settings = interactor.foodLogSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: TimelineActionsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension TimelineActionsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: TimelineActionsDelegate)
        case onDisappear(delegate: TimelineActionsDelegate)
        case onCopyDay(count: Int)
        case onClearDay(count: Int)
        case onActionFail(error: Error)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "TimelineActionsView_Save_Fail"
            case .onAppear:                 return "TimelineActionsView_Appear"
            case .onDisappear:              return "TimelineActionsView_Disappear"
            case .onCopyDay:                return "TimelineActionsView_CopyDay"
            case .onClearDay:               return "TimelineActionsView_ClearDay"
            case .onActionFail:             return "TimelineActionsView_Action_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onCopyDay(count: let count), .onClearDay(count: let count):
                return ["meal_count": count]
            case .onActionFail(error: let error):
                return error.eventParameters
            }
        }
        
        var type: LogType {
            switch self {
            case .saveFail: return .severe
            case .onActionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
