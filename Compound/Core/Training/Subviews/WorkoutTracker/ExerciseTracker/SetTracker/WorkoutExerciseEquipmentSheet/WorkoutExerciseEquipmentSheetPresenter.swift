//
//  WorkoutExerciseEquipmentSheetPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 19/02/2026.
//

import Foundation

struct VariationDisplayItem: Identifiable {
    let id: String
    let name: String
    let resistanceSummary: String
    let supportSummary: String
}

@Observable
@MainActor
class WorkoutExerciseEquipmentSheetPresenter {

    private let interactor: WorkoutExerciseEquipmentSheetInteractor
    private let router: WorkoutExerciseEquipmentSheetRouter

    private(set) var variationItems: [VariationDisplayItem] = []
    var chosenVariationId: String?
    private(set) var isLoading = true
    private(set) var loadError: String?

    private var equipmentNameIndex: [EquipmentRef: String] = [:]

    init(
        interactor: WorkoutExerciseEquipmentSheetInteractor,
        router: WorkoutExerciseEquipmentSheetRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func loadVariations(exercise: WorkoutExerciseModel) async {
        interactor.trackEvent(event: Event.loadVariationsStart)
        chosenVariationId = exercise.chosenVariationId
        isLoading = true
        loadError = nil

        // For old sessions with no stored variations, wait for allExercises to load
        if exercise.equipmentVariations.isEmpty {
            var attempts = 0
            while interactor.allExercises.isEmpty && attempts < 6 {
                try? await Task.sleep(for: .milliseconds(500))
                attempts += 1
            }
        }

        do {
            try performLoadVariations(exercise: exercise)
            interactor.trackEvent(event: Event.loadVariationsSuccess)
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            interactor.trackEvent(event: Event.loadVariationsFail(error: error))
        }
        isLoading = false
    }

    private func performLoadVariations(exercise: WorkoutExerciseModel) throws {
        // Use stored variations if available (new sessions)
        var variations = exercise.equipmentVariations

        // Fall back to allExercises lookup for old sessions (stale templateId)
        if variations.isEmpty {
            let template = interactor.allExercises.first(where: { $0.id == exercise.templateId })
                ?? interactor.allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame })
            variations = template?.equipmentVariations ?? []
        }

        guard !variations.isEmpty else {
            throw LoadError.noVariations
        }

        // Build name index from the catalogue and the user's own machines
        equipmentNameIndex = Dictionary(
            interactor.allEquipmentTypes.map { ($0.ref, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        // Build display items
        variationItems = variations.enumerated().map { index, variation in
            let resistanceSummary = variation.resistanceEquipment.isEmpty
                ? "None"
                : variation.resistanceEquipment.map { equipmentNameIndex[$0] ?? $0.equipmentId }.joined(separator: ", ")
            let supportSummary = variation.supportEquipment.isEmpty
                ? "None"
                : variation.supportEquipment.map { equipmentNameIndex[$0] ?? $0.equipmentId }.joined(separator: ", ")
            return VariationDisplayItem(
                id: variation.id,
                name: "Variation \(index + 1)",
                resistanceSummary: resistanceSummary,
                supportSummary: supportSummary
            )
        }

        if chosenVariationId == nil {
            chosenVariationId = variationItems.first?.id
        }
    }

    /// A tap on a row is the choice: it is applied and the sheet closes. Tapping the one already
    /// chosen just closes.
    func onSelectVariation(id: String, onSelect: (String?) -> Void) {
        if chosenVariationId != id {
            chosenVariationId = id
            interactor.playHaptic(option: .selection)
            onSelect(id)
        }
        dismissScreen()
    }

    /// The row's subtitle: what the variation loads with and what it is braced by, leaving out
    /// either that is "None".
    func detail(for item: VariationDisplayItem) -> String? {
        let parts = [
            item.resistanceSummary == "None" ? nil : String(localized: "Resistance: \(item.resistanceSummary)"),
            item.supportSummary == "None" ? nil : String(localized: "Support: \(item.supportSummary)")
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    func onCancelPressed() {
        dismissScreen()
    }

    private func dismissScreen() {
        router.dismissScreen()
    }
}

private enum LoadError: LocalizedError {
    case noVariations

    var errorDescription: String? {
        switch self {
        case .noVariations:
            return String(localized: "No equipment variations defined for this exercise.")
        }
    }
}

extension WorkoutExerciseEquipmentSheetPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadVariationsStart
        case loadVariationsSuccess
        case loadVariationsFail(error: Error)
        
        var eventName: String {
            switch self {
            case .onAppear: return "WorkoutExerciseEquipmentSheetView_Appear"
            case .onDisappear: return "WorkoutExerciseEquipmentSheetView_Disappear"
            case .loadVariationsStart: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Start"
            case .loadVariationsSuccess: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Success"
            case .loadVariationsFail: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .loadVariationsFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .loadVariationsFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
