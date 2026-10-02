//
//  PrebuiltMesocycleDetailPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2026.
//

import SwiftUI

@Observable
@MainActor
class PrebuiltMesocycleDetailPresenter {

    private let interactor: PrebuiltMesocycleDetailInteractor
    private let router: PrebuiltMesocycleDetailRouter

    let mesocycle: Mesocycle
    private(set) var isStarting = false

    var workoutCount: Int {
        mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty }.count
    }

    init(interactor: PrebuiltMesocycleDetailInteractor, router: PrebuiltMesocycleDetailRouter, mesocycle: Mesocycle) {
        self.interactor = interactor
        self.router = router
        self.mesocycle = mesocycle
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(mesocycleId: mesocycle.id))
    }

    /// Copies the template under the user, makes the copy active, and returns to the library,
    /// where it now shows as the active mesocycle.
    func onStartPressed() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        interactor.trackEvent(event: Event.startStart(mesocycleId: mesocycle.id))
        do {
            _ = try await interactor.startPrebuiltMesocycle(mesocycle)
            interactor.trackEvent(event: Event.startSuccess(mesocycleId: mesocycle.id))
            interactor.playHaptic(option: .success)
            router.dismissScreen()
        } catch {
            interactor.trackEvent(event: Event.startFail(mesocycleId: mesocycle.id, error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Start Mesocycle"), error: error)
        }
    }
}

extension PrebuiltMesocycleDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear(mesocycleId: String)
        case startStart(mesocycleId: String)
        case startSuccess(mesocycleId: String)
        case startFail(mesocycleId: String, error: Error)

        var eventName: String {
            switch self {
            case .onAppear:     return "PrebuiltProgramDetailView_Appear"
            case .startStart:   return "PrebuiltProgramDetailView_Start_Start"
            case .startSuccess: return "PrebuiltProgramDetailView_Start_Success"
            case .startFail:    return "PrebuiltProgramDetailView_Start_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let mesocycleId), .startStart(let mesocycleId), .startSuccess(let mesocycleId):
                return ["program_id": mesocycleId]
            case .startFail(let mesocycleId, let error):
                var params = error.eventParameters
                params["program_id"] = mesocycleId
                return params
            }
        }

        var type: LogType {
            switch self {
            case .startFail: return .severe
            default:         return .analytic
            }
        }
    }
}
