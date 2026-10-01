//
//  CreateWorkoutRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CreateWorkoutRouter: GlobalRouter {
    func showNameWorkoutView(delegate: NameWorkoutDelegate)
}

extension CoreRouter: CreateWorkoutRouter { }
