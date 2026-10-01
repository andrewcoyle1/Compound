//
//  NameWorkoutRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NameWorkoutRouter: GlobalRouter {
    func showChooseGymProfileView(delegate: ChooseGymProfileDelegate)
    func showDefineWorkoutWrapperView(delegate: DefineWorkoutWrapperDelegate)
}

extension CoreRouter: NameWorkoutRouter { }
