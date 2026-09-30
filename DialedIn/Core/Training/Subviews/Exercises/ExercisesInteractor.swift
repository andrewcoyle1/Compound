//
//  ExercisesInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol ExercisesInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
}

extension CoreInteractor: ExercisesInteractor { }
