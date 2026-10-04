//
//  MealDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol MealDetailInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    func deleteDraftMeal() throws
    func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws
}

extension CoreInteractor: MealDetailInteractor { }
