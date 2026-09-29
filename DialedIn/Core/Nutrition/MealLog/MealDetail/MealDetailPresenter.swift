//
//  MealDetailPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/10/2025.
//

import SwiftUI

@Observable
@MainActor
class MealDetailPresenter {
    private let interactor: MealDetailInteractor
    private let router: MealDetailRouter

    init(
        interactor: MealDetailInteractor,
        router: MealDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: MealDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(itemCount: delegate.meal.items.count))
    }

    /// Item nutrients are stored at the amount logged, so a meal's totals are a plain sum — no
    /// scaling, and no need to resolve the underlying foods.
    func macroSummary(for meal: MealLogModel) -> [MacroSummaryItem] {
        let calories = Int(meal.totalCalories.rounded())
        let protein = Int(meal.totalProteinGrams.rounded())
        let carbs = Int(meal.totalCarbGrams.rounded())
        let fat = Int(meal.totalFatGrams.rounded())

        return [
            MacroSummaryItem(label: "Calories", value: String(calories)),
            MacroSummaryItem(label: "Protein", value: "\(protein)g"),
            MacroSummaryItem(label: "Carbs", value: "\(carbs)g"),
            MacroSummaryItem(label: "Fat", value: "\(fat)g")
        ]
    }

    struct MacroSummaryItem: Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onDeletePressed(meal: MealLogModel) {
        // Deleting a logged meal cannot be undone, so it is confirmed first.
        router.showAlert(
            title: String(localized: "Delete this meal?"),
            subtitle: String(localized: "This cannot be undone."),
            buttons: {
                AnyView(
                    Group {
                        Button("Delete", role: .destructive) {
                            self.delete(meal: meal)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func delete(meal: MealLogModel) {
        interactor.trackEvent(event: Event.onDeleteStart)
        Task {
            do {
                try await interactor.deleteMealAndSync(
                    id: meal.mealId,
                    dayKey: meal.dayKey,
                    authorId: meal.authorId
                )
                interactor.trackEvent(event: Event.onDeleteSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.onDeleteFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to delete meal"), subtitle: String(localized: "Please try again."))
            }
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}

extension MealDetailPresenter {

    enum Event: LoggableEvent {
        case onAppear(itemCount: Int)
        case onDeleteStart
        case onDeleteSuccess
        case onDeleteFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:         return "MealDetailView_Appear"
            case .onDeleteStart:    return "MealDetailView_Delete_Start"
            case .onDeleteSuccess:  return "MealDetailView_Delete_Success"
            case .onDeleteFail:     return "MealDetailView_Delete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(itemCount: let count):
                return ["item_count": count]
            case .onDeleteFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onDeleteFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
