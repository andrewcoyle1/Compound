//
//  FoodDetailPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class FoodDetailPresenter {
    private let interactor: FoodDetailInteractor
    private let router: FoodDetailRouter

    var isBookmarked: Bool = false
    var isFavourited: Bool = false

    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    init(
        interactor: FoodDetailInteractor,
        router: FoodDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
        
    func onViewAppear(delegate: FoodDetailDelegate) {
        isFavourited = interactor.isFavouriteFood(id: delegate.food.id)
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    /// Favourites are stored per user on the food log settings, which is what the library's
    /// Favourites tab reads.
    func onFavouritePressed(delegate: FoodDetailDelegate) {
        let newValue = !isFavourited
        isFavourited = newValue
        interactor.trackEvent(event: Event.favouriteIngredientStart)
        Task {
            do {
                try await interactor.setFavouriteFood(id: delegate.food.id, isFavourite: newValue)
                interactor.trackEvent(event: Event.favouriteIngredientSuccess)
            } catch {
                isFavourited = !newValue
                interactor.trackEvent(event: Event.favouriteIngredientFail(error: error))
            }
        }
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    private(set) var isDeleting: Bool = false

    func canDelete(food: FoodModel) -> Bool {
        food.authorId != nil && food.authorId == currentUser?.userId
    }

    func showDeleteConfirmation(food: FoodModel) {
        router.showAlert(title: String(localized: "Delete Food"), subtitle: String(localized: "Are you sure you want to delete '\(food.name)'? This action cannot be undone."), buttons: {
            AnyView(
                HStack {
                    Button("Delete", role: .destructive) {
                        Task {
                            await self.deleteFood(food, onDismiss: { self.router.dismissScreen() })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            )
        })
    }

    /// `onDismiss` is the router's dismiss in the app; a parameter so a test can see it happen.
    func deleteFood(_ food: FoodModel, onDismiss: @escaping () -> Void) async {
        isDeleting = true
        do {
            try await interactor.deleteFood(ingredientId: food.id)
            onDismiss()
        } catch {
            isDeleting = false
            router.showSimpleAlert(title: String(localized: "Failed to delete food"), subtitle: String(localized: "Please try again later"))
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case favouriteIngredientStart
        case favouriteIngredientSuccess
        case favouriteIngredientFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                     return "FoodDetailView_Appear"
            case .onDisappear:                  return "FoodDetailView_Disappear"
            case .favouriteIngredientStart:     return "FoodDetailView_Favourite_Start"
            case .favouriteIngredientSuccess:   return "FoodDetailView_Favourite_Success"
            case .favouriteIngredientFail:      return "FoodDetailView_Favourite_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .favouriteIngredientFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .favouriteIngredientFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
