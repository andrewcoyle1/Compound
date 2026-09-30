//
//  CreatePlanPresenter.swift
//  DialedIn
//
//  Builds a plan from the user's saved programs: each one picked becomes a block, run in the
//  order listed. Starting it replaces whatever plan is being followed.
//

import SwiftUI

@Observable
@MainActor
class CreatePlanPresenter {
    private let interactor: CreatePlanInteractor
    private let router: CreatePlanRouter

    var name: String = ""
    /// Program ids in block order. A program may appear more than once.
    var blockIds: [String] = []
    private(set) var isSaving = false

    init(interactor: CreatePlanInteractor, router: CreatePlanRouter) {
        self.interactor = interactor
        self.router = router
    }

    var programs: [TrainingProgram] {
        interactor.trainingPrograms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var blocks: [(index: Int, program: TrainingProgram)] {
        blockIds.enumerated().compactMap { index, id in
            interactor.trainingPrograms.first { $0.id == id }.map { (index, $0) }
        }
    }

    var canStart: Bool {
        !blockIds.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onProgramPressed(_ program: TrainingProgram) {
        blockIds.append(program.id)
        if name.isEmpty { name = program.name }
        interactor.playHaptic(option: .selection)
    }

    func onMoveBlocks(from source: IndexSet, to destination: Int) {
        blockIds.move(fromOffsets: source, toOffset: destination)
    }

    func onDeleteBlocks(at offsets: IndexSet) {
        blockIds.remove(atOffsets: offsets)
    }

    func onClosePressed() {
        router.dismissScreen()
    }

    func onStartPressed() {
        guard canStart else { return }
        isSaving = true
        interactor.trackEvent(event: Event.startStart(blockCount: blockIds.count))
        Task {
            defer { isSaving = false }
            do {
                try await interactor.startTrainingPlan(name: name.trimmingCharacters(in: .whitespaces), programIds: blockIds)
                interactor.trackEvent(event: Event.startSuccess)
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.startFail(error: error))
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Start Plan"), error: error)
            }
        }
    }
}

extension CreatePlanPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case startStart(blockCount: Int)
        case startSuccess
        case startFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:     return "CreatePlanView_Appear"
            case .startStart:   return "CreatePlanView_Start_Start"
            case .startSuccess: return "CreatePlanView_Start_Success"
            case .startFail:    return "CreatePlanView_Start_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .startStart(let blockCount): return ["plan_block_count": blockCount]
            case .startFail(let error):       return error.eventParameters
            default:                          return nil
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
