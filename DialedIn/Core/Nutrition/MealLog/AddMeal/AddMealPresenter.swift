//
//  AddMealPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class AddMealPresenter {
    private let interactor: AddMealInteractor
    private let router: AddMealRouter
    
    var mealLog: MealLogModel {
        didSet {
            guard !mealLog.items.isEmpty else { return }
            saveDraftMeal()
        }
    }
    
    var showAllNutrients: Bool = false
    var nutritionScope: NutritionScope = .plate
    
    init(
        interactor: AddMealInteractor,
        router: AddMealRouter,
        delegate: AddMealDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.mealLog = delegate.mealLog
    }
    
    func onViewAppear() {
        interactor.trackEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    var currentUser: UserModel? {
        interactor.currentUser
    }
        
    func deleteItems(at offsets: IndexSet) {
        mealLog.items.remove(atOffsets: offsets)
    }
    
    func onEditMealItem(_ item: MealItemModel) {
        router.showMealItemAmountViewView(delegate: MealItemAmountViewDelegate(
            mode: .editItem(item),
            onConfirm: { [weak self] updatedItem in
                guard let self,
                      let idx = self.mealLog.items.firstIndex(where: { $0.itemId == updatedItem.itemId })
                else { return }
                self.mealLog.items[idx] = updatedItem
            }
        ))
    }

    func onShowPickerPressed() {
        let delegate = NutritionLibraryPickerDelegate(
            items: Binding(get: {
                self.mealLog.items
            }, set: { newValues in
                self.mealLog.items = newValues
            }),
            onPick: { newItem in
                self.mealLog.items.append(newItem)
        })
        router.showNutritionLibraryPickerView(delegate: delegate)
    }
    
    // MARK: - Persistence
    
    func saveDraftMeal() {
        do {
            try interactor.updateDraftMeal(mealLog)
        } catch {
            router.showSimpleAlert(title: String(localized: "Unable to Save Progress"), subtitle: String(localized: "We were unable to save your meal. Please try again."))
        }
    }

    func saveMeal() {
        Task {
            interactor.trackEvent(event: Event.saveMealStart)
            do {
                try await interactor.saveMeal(mealLog)
                try interactor.deleteDraftMeal()
                interactor.trackEvent(event: Event.saveMealSuccess)
                self.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.saveMealFail(error: error))
                // Saving is what dismisses this screen. Without this the meal is simply still
                // sitting there, unlogged, with nothing to say the save was even attempted.
                router.showSimpleAlert(
                    title: String(localized: "Unable to Save Meal"),
                    subtitle: "Please check your internet connection and try again."
                )
            }
        }
    }

    func dismissScreen() {
        if self.mealLog.items.isEmpty {
            try? self.interactor.deleteDraftMeal()
        }
        router.dismissScreen()
    }

    // MARK: - Nutrition Display

    var plateCalories: Double { mealLog.totalCalories }
    var plateProtein: Double { mealLog.totalProteinGrams }
    var plateCarbs: Double { mealLog.totalCarbGrams }
    var plateFat: Double { mealLog.totalFatGrams }

    private var committedDailyTotals: DailyMacroTarget? {
        // Silent: computed local read for the preview totals.
        try? interactor.getDailyTotals(dayKey: mealLog.dayKey)
    }

    var displayCalories: Double {
        nutritionScope == .plate ? plateCalories : (committedDailyTotals?.calories ?? 0) + plateCalories
    }
    var displayProtein: Double {
        nutritionScope == .plate ? plateProtein : (committedDailyTotals?.proteinGrams ?? 0) + plateProtein
    }
    var displayCarbs: Double {
        nutritionScope == .plate ? plateCarbs : (committedDailyTotals?.carbGrams ?? 0) + plateCarbs
    }
    var displayFat: Double {
        nutritionScope == .plate ? plateFat : (committedDailyTotals?.fatGrams ?? 0) + plateFat
    }

    var dailyTarget: DailyMacroTarget? {
        guard let plan = interactor.currentDietPlan else { return nil }
        let weekday = Calendar.current.component(.weekday, from: mealLog.date)
        let index = (weekday + 5) % 7 // Sun=1..Sat=7 → Mon=0..Sun=6
        guard plan.days.indices.contains(index) else { return nil }
        return plan.days[index]
    }

    var targetCalories: Double { dailyTarget?.calories ?? 2000 }
    var targetProtein: Double { dailyTarget?.proteinGrams ?? 150 }
    var targetCarbs: Double { dailyTarget?.carbGrams ?? 200 }
    var targetFat: Double { dailyTarget?.fatGrams ?? 65 }

    var calorieLabel: String { "\(Int(displayCalories))/\(Int(targetCalories))" }

    /// Presents the time picker behind the toolbar's date readout.
    var isEditingMealTime: Bool = false

    /// `MealLogModel.date` and `dayKey` are both `let`, so moving a meal means rebuilding it. The
    /// items come across untouched — this changes when the meal was eaten, not what was in it.
    func updateMealTime(_ newDate: Date) {
        mealLog = MealLogModel(
            mealId: mealLog.mealId,
            authorId: mealLog.authorId,
            dayKey: newDate.dayKey,
            date: newDate,
            items: mealLog.items,
            notes: mealLog.notes
        )
    }
    var scopeLabel: String { nutritionScope == .plate ? String(localized: "in plate") : String(localized: "today") }

    // MARK: - Nutrient Breakdown

    /// One nutrient and how much of it the current scope holds.
    struct NutrientAmount: Identifiable {
        let key: NutrientKey
        let value: Double

        var id: String { key.rawValue }
        var name: String { key.name }
    }

    /// Every nutrient in scope. At plate scope that is the plate's own snapshot; at day scope the
    /// day's already-logged meals are added, which needs the meals themselves — `getDailyTotals`
    /// returns only the four macros.
    private var displayNutrients: NutrientMap {
        let plate = mealLog.totalNutrients
        guard nutritionScope == .day else { return plate }

        // Silent: local read for a derived hint; empty is the fallback.
        let logged = (try? interactor.getMeals(for: mealLog.dayKey)) ?? []
        return logged
            .filter { $0.mealId != mealLog.mealId }
            .reduce(plate) { $0 + $1.totalNutrients }
    }

    /// The nutrients of one category that the scope actually has data for.
    ///
    /// Absent nutrients are left out rather than shown as zero: a food whose source did not record
    /// its selenium is not a food containing no selenium, and printing 0 mcg would assert something
    /// the data does not support. A category with nothing recorded yields an empty array, and the
    /// view says so in words.
    func breakdown(for category: Macros) -> [NutrientAmount] {
        let nutrients = displayNutrients
        return nutrients.recordedKeys(in: category).compactMap { key in
            guard let value = nutrients[key] else { return nil }
            return NutrientAmount(key: key, value: value)
        }
    }

    /// Calories are whole; everything else keeps one decimal below 10, where a tenth of a gram is
    /// a meaningful share of the amount, and none above it.
    func formatted(_ amount: NutrientAmount) -> String {
        let unit = amount.key.unit
        if amount.key == .calories {
            return "\(Int(amount.value.rounded())) \(unit)"
        }
        let precision = amount.value < 10 ? 1 : 0
        return "\(amount.value.formatted(.number.precision(.fractionLength(precision)))) \(unit)"
    }
}

extension AddMealPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveMealStart
        case saveMealSuccess
        case saveMealFail(error: Error)
        
        var eventName: String {
            switch self {
            case .onAppear:         return "AddMealView_Appear"
            case .onDisappear:      return "AddMealView_Disappear"
            case .saveMealStart:    return "AddMealView_SaveMeal_Start"
            case .saveMealSuccess:  return "AddMealView_SaveMeal_Success"
            case .saveMealFail:     return "AddMealView_SaveMeal_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
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

enum NutritionScope: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }
    case plate
    case day
}

enum AddMealError: LocalizedError { case noCurrentUser }
