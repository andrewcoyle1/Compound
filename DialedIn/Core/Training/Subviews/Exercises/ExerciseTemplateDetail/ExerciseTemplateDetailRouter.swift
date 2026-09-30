//
//  ExerciseModelDetailRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol ExerciseModelDetailRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
}

extension CoreRouter: ExerciseModelDetailRouter { }
