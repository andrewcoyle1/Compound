//
//  TrainingProgramLibraryPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class TrainingProgramLibraryPresenter {
    private let interactor: TrainingProgramLibraryInteractor
    private let router: TrainingProgramLibraryRouter
    
    var activeTrainingProgram: TrainingProgram? {
        interactor.activeTrainingProgram
    }
    
    var nonActiveTrainingPrograms: [TrainingProgram] {
        savedPrograms.filter { $0.id != activeTrainingProgram?.id }
    }
    
    var savedPrograms: [TrainingProgram] {
        interactor.trainingPrograms
    }

    var prebuiltPrograms: [TrainingProgram] {
        interactor.prebuiltPrograms
    }
    
    init(
        interactor: TrainingProgramLibraryInteractor,
        router: TrainingProgramLibraryRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    /// The `onAppear`/`onDisappear` cases were declared here from the start but the screen had no
    /// hooks to send them, so the program library was the one screen missing from screen views.
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func showDeleteAlert(program: TrainingProgram) {
        router.showAlert(
            title: String(localized: "Delete Program"),
            subtitle: program.id == activeTrainingProgram?.id
                ? "Are you sure you want to delete your active program '\(program.name)'? This will remove all scheduled workouts and you'll need to create or select a new program."
                : "Delete '\(program.name)'? This can't be undone.",
            buttons: {
                AnyView(
                    Group {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            Task {
                                await self.deleteProgram(program)
                            }
                        }
                    }
                )
            }
        )
    }

    func onSavedProgramPressed(_ program: TrainingProgram) {
        router.showEditTrainingProgramView(delegate: EditTrainingProgramDelegate(program: program))
    }
    
    func deleteProgram(_ program: TrainingProgram) async {
        interactor.trackEvent(event: Event.deleteProgramStart)
        do {
            try await interactor.deleteTrainingProgram(programId: program.id)
            interactor.trackEvent(event: Event.deleteProgramSuccess)
        } catch {
            interactor.trackEvent(event: Event.deleteProgramFail(error: error))
            // The program is still listed after a failed delete, so say so rather than leave the
            // confirmation looking like it did nothing.
            router.showSimpleAlert(title: String(localized: "Unable to delete program"), subtitle: String(localized: "Please try again."))
        }
    }
        
    func onPrebuiltProgramPressed(_ program: TrainingProgram) {
        router.showPrebuiltProgramDetailView(program: program)
    }

    func onCreateProgramPressed() {
        router.showCreateProgramView(delegate: CreateProgramDelegate())
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    func dismissScreen() {
        router.dismissScreen()
    }
}

extension TrainingProgramLibraryPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case deleteProgramStart
        case deleteProgramSuccess
        case deleteProgramFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "TrainingProgramLibraryView_Appear"
            case .onDisappear:          return "TrainingProgramLibraryView_Disappear"
            case .deleteProgramStart:   return "TrainingProgramLibraryView_DeleteProgram_Start"
            case .deleteProgramSuccess: return "TrainingProgramLibraryView_DeleteProgram_Success"
            case .deleteProgramFail:    return "TrainingProgramLibraryView_DeleteProgram_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .deleteProgramFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .deleteProgramFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
