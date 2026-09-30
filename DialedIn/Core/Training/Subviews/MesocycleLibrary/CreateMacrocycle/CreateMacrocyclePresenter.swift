//
//  CreateMacrocyclePresenter.swift
//  DialedIn
//
//  Builds a plan from the user's saved mesocycles: each one picked becomes a block, run in the
//  order listed. Starting it replaces whatever plan is being followed.
//

import SwiftUI

@Observable
@MainActor
class CreateMacrocyclePresenter {
    private let interactor: CreateMacrocycleInteractor
    private let router: CreateMacrocycleRouter

    var name: String = ""
    /// Mesocycle ids in block order. A mesocycle may appear more than once.
    var mesocycleIds: [String] = []
    private(set) var isSaving = false

    init(interactor: CreateMacrocycleInteractor, router: CreateMacrocycleRouter) {
        self.interactor = interactor
        self.router = router
    }

    var mesocycles: [Mesocycle] {
        interactor.mesocycles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var blocks: [(index: Int, mesocycle: Mesocycle)] {
        mesocycleIds.enumerated().compactMap { index, id in
            interactor.mesocycles.first { $0.id == id }.map { (index, $0) }
        }
    }

    var canStart: Bool {
        !mesocycleIds.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onMesocyclePressed(_ mesocycle: Mesocycle) {
        mesocycleIds.append(mesocycle.id)
        if name.isEmpty { name = mesocycle.name }
        interactor.playHaptic(option: .selection)
    }

    func onMoveBlocks(from source: IndexSet, to destination: Int) {
        mesocycleIds.move(fromOffsets: source, toOffset: destination)
    }

    func onDeleteBlocks(at offsets: IndexSet) {
        mesocycleIds.remove(atOffsets: offsets)
    }

    func onClosePressed() {
        router.dismissScreen()
    }

    func onStartPressed() {
        guard canStart else { return }
        isSaving = true
        interactor.trackEvent(event: Event.startStart(blockCount: mesocycleIds.count))
        Task {
            defer { isSaving = false }
            do {
                try await interactor.startMacrocycle(name: name.trimmingCharacters(in: .whitespaces), mesocycleIds: mesocycleIds)
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

extension CreateMacrocyclePresenter {
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
