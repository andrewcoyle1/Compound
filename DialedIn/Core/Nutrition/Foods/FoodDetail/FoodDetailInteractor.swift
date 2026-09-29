//
//  FoodDetailInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol FoodDetailInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func isFavouriteFood(id: String) -> Bool
    func setFavouriteFood(id: String, isFavourite: Bool) async throws
    func deleteFood(ingredientId: String) async throws
}

extension CoreInteractor: FoodDetailInteractor { }
