//
//  MealDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol MealDetailInteractor: GlobalInteractor {
    func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws
}

extension CoreInteractor: MealDetailInteractor { }
