//
//  CreateFoodInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol CreateFoodInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws
    func generateImage(input: String) async throws -> UIImage
}

extension CoreInteractor: CreateFoodInteractor { }
