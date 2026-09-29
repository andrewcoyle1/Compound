//
//  NutritionLibraryPickerInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NutritionLibraryPickerInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveExternalFood(_ food: FoodModel) async
}

extension CoreInteractor: NutritionLibraryPickerInteractor {
    func saveExternalFood(_ food: FoodModel) async {
        guard let uid = userId else { return }
        let owned = food.withAuthorId(uid)
        // Silent: caching an external food into the library is a side effect of logging it.
        try? await saveFood(owned, image: nil)
    }
}
