//
//  MesocycleLibraryPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class MesocycleLibraryPresenter {
    private let interactor: MesocycleLibraryInteractor
    private let router: MesocycleLibraryRouter
    
    var activeMesocycle: Mesocycle? {
        interactor.activeMesocycle
    }
    
    var nonActiveMesocycles: [Mesocycle] {
        savedMesocycles.filter { $0.id != activeMesocycle?.id }
    }
    
    var savedMesocycles: [Mesocycle] {
        interactor.mesocycles
    }

    var prebuiltMesocycles: [Mesocycle] {
        interactor.prebuiltMesocycles
    }
    
    init(
        interactor: MesocycleLibraryInteractor,
        router: MesocycleLibraryRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    /// The `onAppear`/`onDisappear` cases were declared here from the start but the screen had no
    /// hooks to send them, so the mesocycle library was the one screen missing from screen views.
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func showDeleteAlert(mesocycle: Mesocycle) {
        router.showAlert(
            title: String(localized: "Delete Mesocycle"),
            subtitle: mesocycle.id == activeMesocycle?.id
                ? String(localized: "Are you sure you want to delete your active mesocycle '\(mesocycle.name)'? This will remove all scheduled workouts and you'll need to create or select a new mesocycle.")
                : String(localized: "Delete '\(mesocycle.name)'? This can't be undone."),
            buttons: {
                AnyView(
                    Group {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            Task {
                                await self.deleteMesocycle(mesocycle)
                            }
                        }
                    }
                )
            }
        )
    }

    func onSavedMesocyclePressed(_ mesocycle: Mesocycle) {
        router.showEditMesocycleView(delegate: EditMesocycleDelegate(mesocycle: mesocycle))
    }
    
    func deleteMesocycle(_ mesocycle: Mesocycle) async {
        interactor.trackEvent(event: Event.deleteMesocycleStart)
        do {
            try await interactor.deleteMesocycle(mesocycleId: mesocycle.id)
            interactor.trackEvent(event: Event.deleteMesocycleSuccess)
        } catch {
            interactor.trackEvent(event: Event.deleteMesocycleFail(error: error))
            // The mesocycle is still listed after a failed delete, so say so rather than leave the
            // confirmation looking like it did nothing.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Mesocycle"), subtitle: String(localized: "Please try again."))
        }
    }
        
    func onPrebuiltMesocyclePressed(_ mesocycle: Mesocycle) {
        router.showPrebuiltMesocycleDetailView(mesocycle: mesocycle)
    }

    func onCreateMesocyclePressed() {
        router.showCreateMesocycleView(delegate: CreateMesocycleDelegate())
    }

}

extension MesocycleLibraryPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case deleteMesocycleStart
        case deleteMesocycleSuccess
        case deleteMesocycleFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "TrainingProgramLibraryView_Appear"
            case .onDisappear:          return "TrainingProgramLibraryView_Disappear"
            case .deleteMesocycleStart:   return "TrainingProgramLibraryView_DeleteProgram_Start"
            case .deleteMesocycleSuccess: return "TrainingProgramLibraryView_DeleteProgram_Success"
            case .deleteMesocycleFail:    return "TrainingProgramLibraryView_DeleteProgram_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .deleteMesocycleFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .deleteMesocycleFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
