//
//  PrebuiltProgramDetailPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

import SwiftUI

@Observable
@MainActor
class PrebuiltProgramDetailPresenter {

    private let interactor: PrebuiltProgramDetailInteractor
    private let router: PrebuiltProgramDetailRouter

    let program: TrainingProgram
    private(set) var isStarting = false

    var workoutCount: Int {
        program.workoutTemplates.filter { !$0.exercises.isEmpty }.count
    }

    init(interactor: PrebuiltProgramDetailInteractor, router: PrebuiltProgramDetailRouter, program: TrainingProgram) {
        self.interactor = interactor
        self.router = router
        self.program = program
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(programId: program.id))
    }

    /// Copies the template under the user, makes the copy active, and returns to the library,
    /// where it now shows as the active program.
    func onStartPressed() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        interactor.trackEvent(event: Event.startStart(programId: program.id))
        do {
            _ = try await interactor.startPrebuiltProgram(program)
            interactor.trackEvent(event: Event.startSuccess(programId: program.id))
            router.dismissScreen()
        } catch {
            interactor.trackEvent(event: Event.startFail(programId: program.id, error: error))
            router.showAlert(error: error)
        }
    }
}

extension PrebuiltProgramDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear(programId: String)
        case startStart(programId: String)
        case startSuccess(programId: String)
        case startFail(programId: String, error: Error)

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
            case .onAppear(let programId), .startStart(let programId), .startSuccess(let programId):
                return ["program_id": programId]
            case .startFail(let programId, let error):
                var params = error.eventParameters
                params["program_id"] = programId
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
