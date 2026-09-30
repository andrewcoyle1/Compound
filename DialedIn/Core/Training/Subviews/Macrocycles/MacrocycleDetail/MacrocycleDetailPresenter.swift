//
//  MacrocycleDetailPresenter.swift
//  DialedIn
//
//  One macrocycle, new or saved: its name, its mesocycles in order, and where to start it. Starting
//  defaults to the first microcycle of the first mesocycle; someone joining part-way picks where
//  they are, and the microcycles before it count as done.
//

import SwiftUI

struct MacrocycleDetailDelegate {
    /// Nil for a new macrocycle.
    var macrocycle: Macrocycle?
}

@Observable
@MainActor
class MacrocycleDetailPresenter {
    private let interactor: MacrocycleDetailInteractor
    private let router: MacrocycleDetailRouter
    private let existing: Macrocycle?

    var name: String
    /// Mesocycle ids in order. A mesocycle may appear more than once.
    var mesocycleIds: [String]
    var startMesocycleIndex = 0 {
        didSet { startMicrocycleIndex = min(startMicrocycleIndex, max(startMicrocycleCount - 1, 0)) }
    }
    var startMicrocycleIndex = 0
    private(set) var isSaving = false

    init(interactor: MacrocycleDetailInteractor, router: MacrocycleDetailRouter, delegate: MacrocycleDetailDelegate) {
        self.interactor = interactor
        self.router = router
        self.existing = delegate.macrocycle
        self.name = delegate.macrocycle?.name ?? ""
        self.mesocycleIds = delegate.macrocycle?.mesocycleIds ?? []
    }

    var isNew: Bool { existing == nil }

    var title: String {
        isNew ? String(localized: "New Macrocycle") : name
    }

    /// The macrocycle being followed right now, so starting it again means starting over.
    var isFollowing: Bool {
        guard let existing else { return false }
        return interactor.currentMacrocycle?.id == existing.id && interactor.currentMacrocycle?.status == .active
    }

    var startButtonTitle: String {
        isFollowing ? String(localized: "Restart Macrocycle") : String(localized: "Start Macrocycle")
    }

    var entries: [(index: Int, mesocycle: Mesocycle)] {
        mesocycleIds.enumerated().compactMap { index, id in
            interactor.mesocycles.first { $0.id == id }.map { (index, $0) }
        }
    }

    var library: [Mesocycle] {
        interactor.mesocycles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var startMicrocycleCount: Int {
        let id = mesocycleIds.indices.contains(startMesocycleIndex) ? mesocycleIds[startMesocycleIndex] : nil
        return max(interactor.mesocycles.first { $0.id == id }?.numMicrocycles ?? 1, 1)
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !mesocycleIds.isEmpty && !isSaving
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(isNew: isNew))
    }

    func onAddMesocyclePressed(_ mesocycle: Mesocycle) {
        mesocycleIds.append(mesocycle.id)
        if name.isEmpty { name = mesocycle.name }
        interactor.playHaptic(option: .selection)
    }

    func onMoveMesocycles(from source: IndexSet, to destination: Int) {
        mesocycleIds.move(fromOffsets: source, toOffset: destination)
        clampStartPoint()
    }

    func onDeleteMesocycles(at offsets: IndexSet) {
        mesocycleIds.remove(atOffsets: offsets)
        clampStartPoint()
    }

    func onSavePressed() {
        guard canSave else { return }
        run(Event.saveFail) { [self] in
            try await interactor.saveMacrocycle(edited())
        }
    }

    /// Asks first when it would replace the macrocycle being followed, or restart this one.
    func onStartPressed() {
        guard canSave else { return }
        guard let current = interactor.currentMacrocycle, current.status == .active else {
            start()
            return
        }
        let confirmTitle = startButtonTitle
        router.showAlert(
            title: isFollowing ? String(localized: "Restart \(current.name)?") : String(localized: "Replace \(current.name)?"),
            subtitle: String(localized: "Progress in the macrocycle you're following stops counting. Your workout history is kept."),
            buttons: {
                AnyView(
                    Group {
                        Button(confirmTitle, role: .destructive) { self.start() }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onDeletePressed() {
        guard let existing else { return }
        router.showAlert(
            title: String(localized: "Delete \(existing.name)?"),
            subtitle: String(localized: "The mesocycles in it are kept. This can't be undone."),
            buttons: {
                AnyView(
                    Group {
                        Button("Delete", role: .destructive) {
                            self.run(Event.deleteFail) { [self] in
                                try await interactor.deleteMacrocycle(existing)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func start() {
        let macrocycle = edited()
        let mesocycleIndex = startMesocycleIndex
        let microcycleIndex = startMicrocycleIndex
        interactor.trackEvent(event: Event.start(mesocycleIndex: mesocycleIndex, microcycleIndex: microcycleIndex))
        run(Event.startFail) { [self] in
            try await interactor.startMacrocycle(macrocycle, atMesocycle: mesocycleIndex, microcycle: microcycleIndex)
        }
    }

    /// Runs a write, then leaves; on failure stays, with an alert.
    private func run(_ failure: @escaping (Error) -> Event, _ write: @escaping () async throws -> Void) {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await write()
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: failure(error))
                interactor.playHaptic(option: .error)
                router.showAlert(error: error)
            }
        }
    }

    private func edited() -> Macrocycle {
        var macrocycle = existing ?? Macrocycle(
            authorId: interactor.userId ?? "",
            name: trimmedName,
            mesocycleIds: mesocycleIds,
            status: .notStarted
        )
        macrocycle.name = trimmedName
        macrocycle.mesocycleIds = mesocycleIds
        return macrocycle
    }

    private func clampStartPoint() {
        startMesocycleIndex = min(startMesocycleIndex, max(mesocycleIds.count - 1, 0))
    }
}

extension MacrocycleDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear(isNew: Bool)
        case start(mesocycleIndex: Int, microcycleIndex: Int)
        case startFail(error: Error)
        case saveFail(error: Error)
        case deleteFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:   return "MacrocycleDetailView_Appear"
            case .start:      return "MacrocycleDetailView_Start"
            case .startFail:  return "MacrocycleDetailView_Start_Fail"
            case .saveFail:   return "MacrocycleDetailView_Save_Fail"
            case .deleteFail: return "MacrocycleDetailView_Delete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let isNew):
                return ["is_new": isNew]
            case .start(let mesocycleIndex, let microcycleIndex):
                return ["start_mesocycle_index": mesocycleIndex, "start_microcycle_index": microcycleIndex]
            case .startFail(let error), .saveFail(let error), .deleteFail(let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .startFail, .saveFail, .deleteFail: return .severe
            default:                                 return .analytic
            }
        }
    }
}
