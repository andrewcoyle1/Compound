//
//  MealHourHeaderPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 10/03/2026.
//

import SwiftUI

@Observable
@MainActor
class MealHourHeaderPresenter {
    private let interactor: MealHourHeaderInteractor
    private let router: MealHourHeaderRouter
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    var showHourlyMacroTotals: Bool { interactor.foodLogSettings.showHourlyMacroTotals }
    var showAddFoodsButton: Bool { interactor.foodLogSettings.showAddFoodsButton }
    
    init(
        interactor: MealHourHeaderInteractor,
        router: MealHourHeaderRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    /// When a new meal logged from this row should be recorded as having been eaten.
    ///
    /// A timeline row is the *start* of its hour, so tapping the 13:00 row at 13:42 files the meal
    /// at 13:00. With `autoSetCurrentTime` on, the exact time is used instead.
    ///
    /// Only for a row on today. The tapped row is the user's unambiguous choice of day, and "now"
    /// is not inside a past one — presetting it there would silently move the meal to today rather
    /// than sharpen its time.
    private func mealTime(for selectedTime: Date) -> Date {
        let now = Date()
        guard interactor.foodLogSettings.autoSetCurrentTime,
              Calendar.current.isDate(selectedTime, inSameDayAs: now) else { return selectedTime }
        return now
    }

    /// The hour's total of one macro across its meals, rounded down to a whole number as the
    /// header prints it.
    func total(of macro: Macro, in meals: [MealLogModel]) -> Int {
        let values: [Double]
        switch macro {
        case .cals: values = meals.map(\.totalCalories)
        case .protein: values = meals.map(\.totalProteinGrams)
        case .carbs: values = meals.map(\.totalCarbGrams)
        case .fat: values = meals.map(\.totalFatGrams)
        }
        return Int(values.reduce(0, +))
    }

    func onAddMealPressed(selectedTime: Date = Date()) {
        guard let userId = currentUser?.userId else { return }
        let mealDate = mealTime(for: selectedTime)
        if let meal = interactor.draftMeal {
            // A choice, not a failure, so an action sheet rather than an alert titled as an error.
            router.showConfirmationDialog(
                title: String(localized: "You have an unlogged meal"),
                subtitle: nil,
                buttons: {
                    AnyView(
                        VStack {
                            Button("Continue Meal") {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(mealLog: meal)
                                )
                            }
                            Button("Discard and Start New", role: .destructive) {
                                try? self.interactor.deleteDraftMeal()
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(
                                        mealLog: MealLogModel(
                                            authorId: userId,
                                            dayKey: mealDate.dayKey,
                                            date: mealDate,
                                            items: []
                                        )
                                    )
                                )
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    )
                }
            )
        } else {
            self.router.showAddMealView(
                delegate: AddMealDelegate(
                    mealLog: MealLogModel(
                        authorId: userId,
                        dayKey: mealDate.dayKey,
                        date: mealDate,
                        items: []
                    )
                )
            )
        }
    }

}
