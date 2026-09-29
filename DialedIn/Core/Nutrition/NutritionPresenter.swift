//
//  NutritionPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class NutritionPresenter {
    private let interactor: NutritionInteractor
    private let router: NutritionRouter
   
    var selectedDate: Date = Date()
    
    var draftMeal: MealLogModel? {
        interactor.draftMeal
    }

    var mealsForSelectedDate: [MealLogModel] {
        // Silent: computed local read; an empty timeline is the fallback.
        (try? interactor.getMeals(for: selectedDate.dayKey)) ?? []
    }

    var dailyTotals: DailyMacroTarget? {
        // Silent: computed local read; no totals shows as no data.
        try? interactor.getDailyTotals(dayKey: dayKey)
    }

    var dailyTarget: DailyMacroTarget? {
        dailyTarget(for: selectedDate)
    }

    /// The plan stores one target per weekday, Monday first.
    private func dailyTarget(for date: Date) -> DailyMacroTarget? {
        guard let plan = interactor.currentDietPlan else { return nil }
        let weekday = Calendar.current.component(.weekday, from: date)
        let dayIndex = (weekday + 5) % 7
        guard dayIndex < plan.days.count else { return nil }
        return plan.days[dayIndex]
    }

    /// One hour of the timeline: the hour itself, and the meals logged inside it.
    struct TimelineHour: Identifiable {
        let id: Date
        var meals: [MealLogModel]

        var hour: Date { id }
    }

    /// The whole timeline for the selected day, built in one pass.
    ///
    /// This replaces a `workingHours` array plus a `meals(inHour:)` lookup the view called per
    /// section. Each of those filtered the full day, and `workingHours` called it once per hour
    /// just to drop the empty ones, so a single body pass scanned the day's meals about thirty
    /// times. Same fix as `CalendarHeaderPresenter.markersByDay` — group once, hand the view the
    /// finished shape.
    var timelineHours: [TimelineHour] {
        let calendar = Calendar.current
        let mealsByHour = Dictionary(grouping: mealsForSelectedDate) { meal in
            calendar.dateInterval(of: .hour, for: meal.date)?.start ?? meal.date
        }

        // An hour holding food is always shown, in or out of the configured window. The window
        // decides how much empty timeline to draw around the day, never whether something logged
        // is reachable: a 2am snack under a 7-23 window used to count toward the day's totals and
        // mark the calendar while appearing nowhere, so it could not be edited or deleted.
        var shownHours = Set(mealsByHour.keys)

        if !hideEmptyHours,
           let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: selectedDate),
           let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: selectedDate) {
            var current = start
            // Step through hour by hour until reaching the end.
            while current <= end {
                shownHours.insert(current)
                guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
                current = next
            }
        }

        return shownHours.sorted().map { hour in
            TimelineHour(id: hour, meals: mealsByHour[hour] ?? [])
        }
    }

    /// How every row in the timeline is drawn, resolved from `FoodLogSettings` in one place
    /// instead of five parameters at the call site.
    var mealItemRowStyle: MealItemRowStyle {
        MealItemRowStyle(
            showsTimestampColumn: showsFoodTimestamps,
            timestampSide: timestampSide,
            showsImage: showFoodImageInTimeline,
            showsCalories: showCaloriesInTimeline,
            showsMacros: showMacrosInTimeline
        )
    }

    /// The gutter time for a row. Only a meal's first item carries one, so several items logged
    /// together read as a single block rather than repeating the same time down the page.
    ///
    /// Compares ids, not whole items: two helpings of the same food at the same amount are equal
    /// by value, and the second would then have printed the time as well.
    func timestamp(for item: MealItemModel, in meal: MealLogModel) -> Date? {
        item.id == meal.items.first?.id ? meal.date : nil
    }

    var hideEmptyHours: Bool { interactor.foodLogSettings.hideEmptyHours }

    /// When on, timeline rows collapse to the food name alone, whatever the individual
    /// image/calorie/macro toggles say.
    var hideFoodDetails: Bool { interactor.foodLogSettings.hideFoodDetails }
    
    var caloriePercentage: Double {
        guard let target = dailyTarget?.calories, target > 0 else { return 0 }
        return (dailyTotals?.calories ?? 0) / target
    }
    
    var proteinPercentage: Double {
        guard let target = dailyTarget?.proteinGrams, target > 0 else { return 0 }
        return (dailyTotals?.proteinGrams ?? 0) / target
    }

    var fatPercentage: Double {
        guard let target = dailyTarget?.fatGrams, target > 0 else { return 0 }
        return (dailyTotals?.fatGrams ?? 0) / target
    }

    var carbsPercentage: Double {
        guard let target = dailyTarget?.carbGrams, target > 0 else { return 0 }
        return (dailyTotals?.carbGrams ?? 0) / target
    }

    var showCalendarWeekBanner: Bool { interactor.foodLogSettings.showCalendarWeekBanner }
    var showsFoodTimestamps: Bool { interactor.foodLogSettings.showsFoodTimestamps }
    var startHour: Int { interactor.foodLogSettings.startHour }
    var endHour: Int { interactor.foodLogSettings.endHour }
    var timestampSide: TimestampSide { interactor.foodLogSettings.timestampSide }
    var showCaloriesRing: Bool { interactor.foodLogSettings.showCaloriesRing }
    var showProteinRing: Bool { interactor.foodLogSettings.showProteinRing }
    var showFatRing: Bool { interactor.foodLogSettings.showFatRing }
    var showCarbsRing: Bool { interactor.foodLogSettings.showCarbsRing }
    var showOverages: Bool { interactor.foodLogSettings.showOverages }
    var showFoodImageInTimeline: Bool { !hideFoodDetails && interactor.foodLogSettings.showFoodImageInTimeline }
    var showCaloriesInTimeline: Bool { !hideFoodDetails && interactor.foodLogSettings.showCaloriesInTimeline }
    var showMacrosInTimeline: Bool { !hideFoodDetails && interactor.foodLogSettings.showMacrosInTimeline }

    var currentUser: UserModel? {
        interactor.currentUser
    }

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    var dayKey: String {
        selectedDate.dayKey
    }
    
    init(
        interactor: NutritionInteractor,
        router: NutritionRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: NutritionDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        scheduleMealRemindersIfNeeded()
    }

    func onViewDisappear(delegate: NutritionDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    private func scheduleMealRemindersIfNeeded() {
        let key = "hasMealRemindersScheduled"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        Task {
            do {
                try await interactor.scheduleMealReminderNotifications()
                UserDefaults.standard.set(true, forKey: key)
            } catch {
                // Silent — non-critical
            }
        }
    }
    
    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }

    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif

//    func saveMeal(_ meal: MealLogModel) async {
//        do {
//            try await interactor.addMeal(meal)
//        } catch {
//            router.showAlert(error: error)
//        }
//    }
    
    func deleteMealItem(_ item: MealItemModel, from meal: MealLogModel) {
        var updatedMeal = meal
        updatedMeal.items.removeAll { $0.itemId == item.itemId }
        Task {
            interactor.trackEvent(event: Event.saveMealStart)
            do {
                if updatedMeal.items.isEmpty {
                    try await interactor.deleteMealAndSync(
                        id: meal.mealId,
                        dayKey: meal.dayKey,
                        authorId: meal.authorId
                    )
                } else {
                    try await interactor.addMeal(updatedMeal)
                }
                interactor.trackEvent(event: Event.saveMealSuccess)
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.saveMealFail(error: error))
            }
        }
    }

    func deleteMeal(_ meal: MealLogModel) {
        Task {
            interactor.trackEvent(event: Event.saveMealStart)
            do {
                try await interactor.deleteMealAndSync(
                    id: meal.mealId,
                    dayKey: meal.dayKey,
                    authorId: meal.authorId
                )
                interactor.trackEvent(event: Event.saveMealSuccess)
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.saveMealFail(error: error))
            }
        }
    }

    func onEditMealItem(_ item: MealItemModel) {
        router.showMealItemAmountViewView(
            delegate: MealItemAmountViewDelegate(
                mode: .editItem(item),
                onConfirm: { _ in
                    
                }
            )
        )
    }
    
    func onViewMealPressed(_ meal: MealLogModel) {
        router.showMealDetailView(delegate: MealDetailDelegate(meal: meal))
    }

    func onTimelineActionsPressed() {
        router.showTimelineActionsView(delegate: TimelineActionsDelegate(date: selectedDate))
    }
    
    func onCustomiseFoodLogPressed() {
        router.showFoodLogSettingsView(delegate: FoodLogSettingsDelegate())
    }
    
    func onNutritionOverviewPressed() {
        router.showNutritionOverviewView(delegate: NutritionOverviewDelegate(dayKey: dayKey))
    }

    /// Going over the day's calorie goal by a little is not worth flagging, so the ring only
    /// reads as over once this allowance on top of the goal is used up too.
    static let calorieGrace: Double = 100

    /// Calories logged per day against that day's goal, in one pass. Per-day lookups went
    /// through `Date.dayKey`, which builds a `DateFormatter` on every call, once per visible
    /// calendar cell.
    ///
    /// A day with no goal in the plan falls back to a plain "something was logged" mark, since
    /// a ring with nothing to fill toward would read as 0%.
    func calorieMarkersByDay() -> [Date: CalendarDayMarker] {
        let calendar = Calendar.current
        let caloriesByDay = interactor.userMeals.reduce(into: [Date: Double]()) { calories, meal in
            calories[calendar.startOfDay(for: meal.date), default: 0] += meal.totalCalories
        }

        return caloriesByDay.reduce(into: [Date: CalendarDayMarker]()) { markers, entry in
            let (day, calories) = entry
            guard let goal = dailyTarget(for: day)?.calories, goal > 0 else {
                markers[day] = .count(1)
                return
            }
            markers[day] = .goalProgress(value: calories, goal: goal, grace: Self.calorieGrace)
        }
    }
}

extension NutritionPresenter {
    enum Event: LoggableEvent {
        case onAppear(delegate: NutritionDelegate)
        case onDisappear(delegate: NutritionDelegate)
        case saveMealStart
        case saveMealSuccess
        case saveMealFail(error: Error)
        
        var eventName: String {
            switch self {
            case .onAppear:         return "NutritionView_Appear"
            case .onDisappear:      return "NutritionView_Disappear"
            case .saveMealStart:    return "NutritionView_SaveMeal_Start"
            case .saveMealSuccess:  return "NutritionView_SaveMeal_Success"
            case .saveMealFail:     return "NutritionView_SaveMeal_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .saveMealFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveMealFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
