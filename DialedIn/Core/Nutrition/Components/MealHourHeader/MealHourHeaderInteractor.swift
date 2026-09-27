//
//  MealHourHeaderInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/03/2026.
//

@MainActor
protocol MealHourHeaderInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    var foodLogSettings: FoodLogSettings { get }
    func deleteDraftMeal() throws
}

extension CoreInteractor: MealHourHeaderInteractor { }
