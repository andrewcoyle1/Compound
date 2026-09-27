//
//  MealHourHeaderRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/03/2026.
//

@MainActor
protocol MealHourHeaderRouter: GlobalRouter {
    func showAddMealView(delegate: AddMealDelegate)
}

extension CoreRouter: MealHourHeaderRouter { }
