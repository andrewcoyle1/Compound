//
//  MacrocyclesPresenter.swift
//  Compound
//
//  Every macrocycle the user has: the one being followed first, then the rest, newest first.
//

import SwiftUI

@Observable
@MainActor
class MacrocyclesPresenter {
    private let interactor: MacrocyclesInteractor
    private let router: MacrocyclesRouter

    init(interactor: MacrocyclesInteractor, router: MacrocyclesRouter) {
        self.interactor = interactor
        self.router = router
    }

    var current: Macrocycle? {
        interactor.currentMacrocycle
    }

    var others: [Macrocycle] {
        interactor.macrocycles
            .filter { $0.id != current?.id }
            .sorted { $0.dateModified > $1.dateModified }
    }

    var isEmpty: Bool {
        current == nil && others.isEmpty
    }

    func subtitle(for macrocycle: Macrocycle) -> String {
        let count = String(localized: "\(macrocycle.mesocycleIds.count) mesocycles")
        let status: String
        switch macrocycle.status {
        case .active:
            status = String(localized: "Mesocycle \(macrocycle.mesocycleIndex + 1) of \(macrocycle.mesocycleIds.count)")
        case .completed:  status = String(localized: "Complete")
        case .notStarted: status = String(localized: "Not started")
        case .ended:      status = String(localized: "Ended")
        }
        return "\(count) · \(status)"
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onNewMacrocyclePressed() {
        router.showMacrocycleDetailView(delegate: MacrocycleDetailDelegate())
    }

    func onMacrocyclePressed(_ macrocycle: Macrocycle) {
        router.showMacrocycleDetailView(delegate: MacrocycleDetailDelegate(macrocycle: macrocycle))
    }

    /// A program sheet or file becomes a macrocycle of its blocks; once saved, its detail opens
    /// so it can be started from here.
    func onImportProgramPressed() {
        interactor.trackEvent(event: Event.importProgramPressed)
        router.showImportProgramView(delegate: ImportProgramDelegate(onImported: { [weak self] macrocycle in
            self?.openImported(macrocycle)
        }))
    }

    /// The importer dismisses its sheet first; the push waits for that to land.
    private func openImported(_ macrocycle: Macrocycle) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.router.showMacrocycleDetailView(delegate: MacrocycleDetailDelegate(macrocycle: macrocycle))
        }
    }
}

extension MacrocyclesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case importProgramPressed

        var eventName: String {
            switch self {
            case .onAppear:              return "MacrocyclesView_Appear"
            case .onDisappear:           return "MacrocyclesView_Disappear"
            case .importProgramPressed:  return "MacrocyclesView_ImportProgram_Pressed"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
