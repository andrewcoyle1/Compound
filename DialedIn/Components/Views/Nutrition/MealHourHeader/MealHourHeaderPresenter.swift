//
//  MealHourHeaderPresenter.swift
//  DialedIn
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

    func onAddMealPressed(selectedTime: Date = Date()) {
        guard let userId = currentUser?.userId else { return }
        let mealDate = mealTime(for: selectedTime)
        if let meal = interactor.draftMeal {
            router.showAlert(
                title: String(localized: "Unable to add new meal"),
                subtitle: String(localized: "You already have an draft meal."),
                buttons: {
                    AnyView(
                        VStack {
                            Button("Continue editing") {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(mealLog: meal)
                                )
                            }
                            Button("Delete drafted meal", role: .destructive) {
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
