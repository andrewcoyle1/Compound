//
//  TrainingAccessoryRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/01/2026.
//

protocol TrainingAccessoryRouter: GlobalRouter {
    func showWorkoutTrackerView()
}

extension CoreRouter: TrainingAccessoryRouter {}
