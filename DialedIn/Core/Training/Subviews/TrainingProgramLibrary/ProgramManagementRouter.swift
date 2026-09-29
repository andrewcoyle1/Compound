//
//  TrainingProgramLibraryRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol TrainingProgramLibraryRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showProgramSettingsView(program: Binding<TrainingProgram>)
    func showCreateProgramView(delegate: CreateProgramDelegate)
    func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate)
    func showPrebuiltProgramDetailView(program: TrainingProgram)
}

extension CoreRouter: TrainingProgramLibraryRouter { }
