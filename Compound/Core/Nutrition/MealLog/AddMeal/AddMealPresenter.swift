//
//  AddMealPresenter.swift
//  Compound
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
    
    /// How long the cover gets to finish arriving before the picker opens over it. A sheet
    /// presented while the cover is still animating in is dropped by the system and reported as
    /// dismissed; SwiftfulRouting waits the same 0.55 s between back-to-back presentations.
    /// Injectable so a test need not wait it out.
    private let pickerDelay: Duration

    init(
        interactor: AddMealInteractor,
        router: AddMealRouter,
        delegate: AddMealDelegate,
        pickerDelay: Duration = .milliseconds(550)
    ) {
        self.interactor = interactor
        self.router = router
        self.mealLog = delegate.mealLog
        self.pickerDelay = pickerDelay
    }
    
    /// Set once the picker has opened by itself, so closing it back to the plate does not reopen it.
    private var hasOpenedPicker = false
    private var isPickerShowing = false

    /// A new meal opens straight on the picker: an empty plate has nothing to do but add food.
    func onViewAppear() {
        interactor.trackEvent(event: Event.onAppear)
        guard !hasOpenedPicker, mealLog.items.isEmpty else { return }
        hasOpenedPicker = true
        Task {
            try? await Task.sleep(for: pickerDelay)
            onShowPickerPressed()
        }
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
            item: item,
            onConfirm: { [weak self] updatedItem in
                guard let self,
                      let idx = self.mealLog.items.firstIndex(where: { $0.itemId == updatedItem.itemId })
                else { return }
                self.mealLog.items[idx] = updatedItem
            }
        ))
    }

    func onDeleteMealItem(_ item: MealItemModel) {
        mealLog.items.removeAll { $0.itemId == item.itemId }
    }

    func onNutritionScopeChanged() {
        interactor.playHaptic(option: .selection)
    }

    func onShowPickerPressed() {
        let delegate = NutritionLibraryPickerDelegate(
            plate: { self.mealLog.items },
            onPick: { newItem in
                self.mealLog.items.append(newItem)
            },
            onLog: { [weak self] in
                self?.logFromPicker()
            },
            onAppear: { [weak self] in
                self?.isPickerShowing = true
            },
            // Closing the picker with nothing picked means nothing is being logged: leave the
            // logger rather than stop on an empty plate. Only if it was ever on screen: a
            // presentation the system dropped is reported as dismissed too, and that has to leave
            // the plate and its Add Food, not close the logger under the user's tap.
            onDidDismiss: { [weak self] in
                guard let self else { return }
                defer { isPickerShowing = false }
                if closeOnceThePickerHasGone {
                    dismissScreen()
                    return
                }
                guard isPickerShowing, mealLog.items.isEmpty, !isSaving else { return }
                dismissScreen()
            }
        )
        hasOpenedPicker = true
        router.showNutritionLibraryPickerView(delegate: delegate)
    }
    
    // MARK: - Persistence
    
    func saveDraftMeal() {
        do {
            try interactor.updateDraftMeal(mealLog)
        } catch {
            interactor.trackEvent(event: Event.saveDraftFail(error: error))
            router.showSimpleAlert(title: String(localized: "Unable to Save Progress"), subtitle: String(localized: "We were unable to save your meal. Please try again."))
        }
    }

    /// Set while the meal is being logged, so a second tap cannot log it twice.
    private(set) var isSaving: Bool = false

    func saveMeal() {
        saveMeal(thenDismiss: dismissScreen)
    }

    /// Set when the picker's Log has saved the meal and closed the picker, so the logger closes
    /// once the picker has gone.
    private var closeOnceThePickerHasGone = false

    /// The picker's Log, and the amount screen's. iOS will not dismiss this cover in the same
    /// update as the sheet over it: dismissing both at once closed only the top screen and left a
    /// logged meal on screen. So the picker goes first and `onDidDismiss` takes the logger after it.
    private func logFromPicker() {
        saveMeal { [weak self] in
            self?.closeOnceThePickerHasGone = true
            self?.router.dismissLastEnvironment()
        }
    }

    private func saveMeal(thenDismiss dismiss: @escaping () -> Void) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            interactor.trackEvent(event: Event.saveMealStart)
            do {
                try await interactor.saveMeal(mealLog)
                // The meal is saved at this point. A draft that will not delete must not report
                // the save as failed: the screen stayed open and a second Log saved it twice.
                try? interactor.deleteDraftMeal()
                interactor.trackEvent(event: Event.saveMealSuccess)
                interactor.playHaptic(option: .success)
                dismiss()
            } catch {
                interactor.trackEvent(event: Event.saveMealFail(error: error))
                interactor.playHaptic(option: .error)
                // Saving is what dismisses this screen. Without this the meal is simply still
                // sitting there, unlogged, with nothing to say the save was even attempted.
                router.showSimpleAlert(
                    title: String(localized: "Unable to Save Meal"),
                    subtitle: String(localized: "Please check your internet connection and try again.")
                )
            }
        }
    }

    func dismissScreen() {
        if self.mealLog.items.isEmpty {
            do {
                try self.interactor.deleteDraftMeal()
            } catch {
                interactor.trackEvent(event: Event.deleteDraftFail(error: error))
            }
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

    /// The time before the picker opened, so Cancel can put it back. The picker applies each
    /// change as it is made.
    private var mealTimeBeforeEditing: Date?

    func onEditMealTimePressed() {
        mealTimeBeforeEditing = mealLog.date
        isEditingMealTime = true
    }

    func onMealTimeCancelled() {
        if let mealTimeBeforeEditing, mealTimeBeforeEditing != mealLog.date {
            updateMealTime(mealTimeBeforeEditing)
        }
        isEditingMealTime = false
    }

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
        case saveDraftFail(error: Error)
        case deleteDraftFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:         return "AddMealView_Appear"
            case .onDisappear:      return "AddMealView_Disappear"
            case .saveMealStart:    return "AddMealView_SaveMeal_Start"
            case .saveMealSuccess:  return "AddMealView_SaveMeal_Success"
            case .saveMealFail:     return "AddMealView_SaveMeal_Fail"
            case .saveDraftFail:    return "AddMealView_SaveDraft_Fail"
            case .deleteDraftFail:  return "AddMealView_DeleteDraft_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveMealFail(error: let error), .saveDraftFail(error: let error), .deleteDraftFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveMealFail, .saveDraftFail:
                return .severe
            case .deleteDraftFail:
                return .warning
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

    var title: String {
        switch self {
        case .plate: return String(localized: "Plate")
        case .day: return String(localized: "Day")
        }
    }
}

enum AddMealError: LocalizedError { case noCurrentUser }
