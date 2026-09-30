//
//  MealAccessoryPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// The tab bar's "Unlogged meal" accessory. SwiftUI keeps its presenter for as long as the
/// accessory stays up, so the presenter must follow the draft as it changes.
@MainActor
struct MealAccessoryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MealAccessoryInteractor {
        var draftMeal: MealLogModel?
    }

    private final class Router: MealAccessoryRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var opened: [MealLogModel] = []
        func showAddMealView(delegate: AddMealDelegate) { opened.append(delegate.mealLog) }
    }

    private func meal(itemCount: Int) -> MealLogModel {
        let items = (0..<itemCount).map { index in
            MealItemModel(
                itemId: "item-\(index)",
                sourceType: .ingredient,
                sourceId: "source-\(index)",
                displayName: "Food \(index)",
                amount: 100,
                unit: "g",
                resolvedGrams: 100,
                nutrients: NutrientMap([.calories: 100])
            )
        }
        return MealLogModel(mealId: "draft", authorId: "user-1", dayKey: Date().dayKey, date: Date(), items: items, notes: nil)
    }

    @Test("Follows the draft after it changes, and reopens the current draft")
    func followsDraftAfterItChanges() {
        let interactor = Interactor()
        let router = Router()
        let first = meal(itemCount: 1)
        interactor.draftMeal = first
        let presenter = MealAccessoryPresenter(
            interactor: interactor,
            router: router,
            delegate: MealAccessoryDelegate(draftMeal: first)
        )

        interactor.draftMeal = meal(itemCount: 3)

        #expect(presenter.draftMeal.items.count == 3)
        presenter.reopenMealLog()
        #expect(router.opened.map(\.items.count) == [3])
    }
}
