//
//  WorkoutSessionDetailRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/11/2025.
//

import SwiftUI

@MainActor
protocol WorkoutSessionDetailRouter: ShareSheetRouter, AskCoachRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showExercisesPickerView(delegate: ExercisesPickerDelegate)
    func showSessionStartTimeView(date: Binding<Date>, onSave: @escaping () -> Void)
    func showSessionDurationView(hours: Binding<Int>, minutes: Binding<Int>, onSave: @escaping () -> Void)
}

extension CoreRouter: WorkoutSessionDetailRouter { }
