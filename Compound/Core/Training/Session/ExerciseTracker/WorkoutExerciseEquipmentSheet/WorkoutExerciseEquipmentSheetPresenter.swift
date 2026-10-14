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
    /// `nil` when the variation lists none.
    let resistanceSummary: String?
    let supportSummary: String?
    /// Whether the workout's gym has every item it needs switched on.
    var isAvailable = true
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
    private var variations: [EquipmentVariation] = []
    private var exercise: WorkoutExerciseModel?

    init(
        interactor: WorkoutExerciseEquipmentSheetInteractor,
        router: WorkoutExerciseEquipmentSheetRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func loadVariations(exercise: WorkoutExerciseModel) async {
        interactor.trackEvent(event: Event.loadVariationsStart)
        self.exercise = exercise
        chosenVariationId = exercise.chosenVariationId
        isLoading = true
        loadError = nil

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
            let template = exercise.libraryModel(in: interactor.allExercises)
                ?? interactor.allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame })
            variations = template?.equipmentVariations ?? []
        }

        guard !variations.isEmpty else {
            throw LoadError.noVariations
        }
        self.variations = variations

        // Build name index from the catalogue and the user's own machines
        equipmentNameIndex = Dictionary(
            interactor.allEquipmentTypes.map { ($0.ref, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        // Build display items, each marked when the workout's gym cannot make it up.
        let available = interactor.workoutGymProfile.map { Set($0.allEquipment.filter(\.isActive).map(\.ref)) }
        let summary = { (refs: [EquipmentRef]) -> String? in
            refs.isEmpty ? nil : refs.map { self.equipmentNameIndex[$0] ?? $0.fallbackName }.joined(separator: ", ")
        }
        variationItems = variations.enumerated().map { index, variation in
            VariationDisplayItem(
                id: variation.id,
                name: String(localized: "Variation \(String(describing: index + 1))"),
                resistanceSummary: summary(variation.resistanceEquipment),
                supportSummary: summary(variation.supportEquipment),
                isAvailable: available.map { Set(variation.resistanceEquipment + variation.supportEquipment).isSubset(of: $0) } ?? true
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
            item.resistanceSummary.map { String(localized: "Resistance: \($0)") },
            item.supportSummary.map { String(localized: "Support: \($0)") },
            item.isAvailable ? nil : String(localized: "Not in this gym")
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    /// Equipment can be edited only in the gym the workout loads from.
    var canEditEquipment: Bool { interactor.workoutGymProfile != nil }

    /// The variation's equipment in the workout's gym, on the gym profile screen: switched on or
    /// off, and its weights, bars and stacks edited. Each save reaches the exercise through
    /// `onGymEdited`, and this list's "Not in this gym" follows.
    func onEditVariationPressed(_ item: VariationDisplayItem, onGymEdited: @escaping @MainActor (GymProfileModel) -> Void) {
        guard let gym = interactor.workoutGymProfile, let variation = variations.first(where: { $0.id == item.id }) else { return }
        interactor.trackEvent(event: Event.editVariationPressed)
        router.showGymProfileView(delegate: GymProfileDelegate(
            gymProfile: gym,
            equipment: Set(variation.resistanceEquipment + variation.supportEquipment),
            title: item.name
        ) { [weak self] saved in
            onGymEdited(saved)
            if let self, let exercise = self.exercise {
                try? self.performLoadVariations(exercise: exercise)
            }
        })
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
        case editVariationPressed
        
        var eventName: String {
            switch self {
            case .onAppear: return "WorkoutExerciseEquipmentSheetView_Appear"
            case .onDisappear: return "WorkoutExerciseEquipmentSheetView_Disappear"
            case .loadVariationsStart: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Start"
            case .loadVariationsSuccess: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Success"
            case .loadVariationsFail: return "WorkoutExerciseEquipmentSheetView_LoadVariations_Fail"
            case .editVariationPressed: return "WorkoutExerciseEquipmentSheetView_EditVariation_Pressed"
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
