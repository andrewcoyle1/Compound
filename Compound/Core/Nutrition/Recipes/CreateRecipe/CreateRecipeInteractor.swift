//
//  CreateRecipeInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol CreateRecipeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
}

extension CoreInteractor: CreateRecipeInteractor { }
