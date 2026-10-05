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

    func onDismissPressed() {
        router.dismissScreen()
    }

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
            interactor.trackEvent(event: Event.saveStart)
            do {
                try await interactor.saveFoodLogSettings(settings)
                interactor.trackEvent(event: Event.saveSuccess)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                interactor.playHaptic(option: .error)
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
    /// Set while a copy or clear is writing, so a second tap cannot copy the day twice.
    private(set) var isWorking: Bool = false

    func onCopyDayConfirmed(delegate: TimelineActionsDelegate) {
        guard !isWorking, let authorId = interactor.currentUser?.userId else { return }
        // A failed local read falls through to the "Nothing to Copy" alert below.
        let meals = loggedMeals(on: delegate.date)
        guard !meals.isEmpty else {
            isChoosingCopyDestination = false
            router.showSimpleAlert(title: String(localized: "Nothing to Copy"), subtitle: String(localized: "This day has no meals logged."))
            return
        }

        let destination = copyDestination
        interactor.trackEvent(event: Event.onCopyDay(count: meals.count))
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                for meal in meals {
                    try await interactor.saveMeal(copy(of: meal, to: destination, authorId: authorId))
                }
                interactor.trackEvent(event: Event.copyDaySuccess(count: meals.count))
                interactor.playHaptic(option: .success)
                isChoosingCopyDestination = false
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.onActionFail(error: error))
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Copy Day"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// The day's meals, or none if the local read fails.
    private func loggedMeals(on date: Date) -> [MealLogModel] {
        do {
            return try interactor.getMeals(for: date.dayKey)
        } catch {
            interactor.trackEvent(event: Event.getMealsFail(error: error))
            return []
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
        // A failed local read falls through to the empty-day guard below.
        let meals = loggedMeals(on: delegate.date)
        guard !meals.isEmpty else {
            router.showSimpleAlert(title: String(localized: "Nothing to Clear"), subtitle: String(localized: "This day has no meals logged."))
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
        guard !isWorking else { return }
        interactor.trackEvent(event: Event.onClearDay(count: meals.count))
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                for meal in meals {
                    try await interactor.deleteMealAndSync(
                        id: meal.mealId,
                        dayKey: meal.dayKey,
                        authorId: meal.authorId
                    )
                }
                interactor.trackEvent(event: Event.clearDaySuccess(count: meals.count))
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.onActionFail(error: error))
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Clear Day"), subtitle: String(localized: "Please try again."))
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
        case saveStart
        case saveSuccess
        case copyDaySuccess(count: Int)
        case clearDaySuccess(count: Int)
        case getMealsFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "TimelineActionsView_Save_Fail"
            case .saveStart:                return "TimelineActionsView_Save_Start"
            case .saveSuccess:              return "TimelineActionsView_Save_Success"
            case .copyDaySuccess:           return "TimelineActionsView_CopyDay_Success"
            case .clearDaySuccess:          return "TimelineActionsView_ClearDay_Success"
            case .getMealsFail:             return "TimelineActionsView_GetMeals_Fail"
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
            case .onCopyDay(count: let count), .onClearDay(count: let count),
                 .copyDaySuccess(count: let count), .clearDaySuccess(count: let count):
                return ["meal_count": count]
            case .onActionFail(error: let error), .getMealsFail(error: let error):
                return error.eventParameters
            case .saveStart, .saveSuccess:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveFail: return .severe
            case .onActionFail:
                return .severe
            case .getMealsFail:
                return .warning
            default:
                return .analytic
            }
        }
    }

}
