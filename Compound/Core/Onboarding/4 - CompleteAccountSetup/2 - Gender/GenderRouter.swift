//
//  GenderRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol GenderRouter: GlobalRouter {
    func showDateOfBirthView(delegate: DateOfBirthDelegate)
}

extension CoreRouter: GenderRouter { }
