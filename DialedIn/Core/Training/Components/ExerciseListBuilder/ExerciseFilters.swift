//
//  ExerciseFilters.swift
//  DialedIn
//

import Foundation

/// The state behind the exercise list's filter bar.
///
/// The bar shipped with nine chips whose actions were all empty. Each one names a field the
/// exercise library already stores, so this is the shape they were reaching for: one value the
/// presenter owns, and one `matches(_:)` that every list in the screen runs through.
struct ExerciseFilters {

    /// Which library an exercise came from. Not a `Set`, because "mine" and "official" together is
    /// just "all", and offering it as two checkboxes invites the empty selection that means nothing.
    enum LibraryScope: String, CaseIterable, Identifiable {
        case all
        case mine
        case official

        var id: String { rawValue }

        var name: String {
            switch self {
            case .all:      return String(localized: "All Exercises")
            case .mine:     return String(localized: "My Exercises")
            case .official: return String(localized: "Official Exercises")
            }
        }
    }

    var types: Set<ExerciseType> = []
    var lateralities: Set<Laterality> = []
    var resistanceKinds: Set<EquipmentKind> = []
    var supportKinds: Set<EquipmentKind> = []

    /// Range of motion and stability are 0...5 ratings, so these are floors rather than matches:
    /// "at least this much" is the question worth asking of a rating.
    var minimumRangeOfMotion: Int?
    var minimumStability: Int?

    var library: LibraryScope = .all

    /// The gym whose equipment an exercise has to be performable with, or nil for any equipment.
    var gymProfileId: String?

    var isActive: Bool {
        !types.isEmpty
            || !lateralities.isEmpty
            || !resistanceKinds.isEmpty
            || !supportKinds.isEmpty
            || minimumRangeOfMotion != nil
            || minimumStability != nil
            || library != .all
            || gymProfileId != nil
    }

    mutating func reset() {
        self = ExerciseFilters()
    }

    /// `availableEquipment` is the chosen gym's active equipment, empty when no gym is chosen. An
    /// empty set with a gym chosen means a gym with nothing in it, which correctly matches only
    /// bodyweight work.
    ///
    /// Split into one predicate per dimension: as a single function this tripped SwiftLint's
    /// cyclomatic complexity limit, and the parts read better named anyway.
    func matches(_ exercise: ExerciseModel, availableEquipment: Set<EquipmentRef>) -> Bool {
        matchesTaxonomy(exercise)
            && matchesEquipment(exercise)
            && matchesRatings(exercise)
            && matchesLibrary(exercise)
            && matchesGym(exercise, availableEquipment: availableEquipment)
    }

    private func matchesTaxonomy(_ exercise: ExerciseModel) -> Bool {
        if !types.isEmpty {
            guard let type = exercise.type, types.contains(type) else { return false }
        }
        if !lateralities.isEmpty {
            guard let laterality = exercise.laterality, lateralities.contains(laterality) else { return false }
        }
        return true
    }

    /// An exercise matches when *any* of its variations uses a selected kind — variations are
    /// alternative ways to perform it, so one qualifying variation is enough.
    private func matchesEquipment(_ exercise: ExerciseModel) -> Bool {
        if !resistanceKinds.isEmpty {
            let kinds = Set(exercise.equipmentVariations.flatMap { $0.resistanceEquipment }.map(\.kind))
            guard !kinds.isDisjoint(with: resistanceKinds) else { return false }
        }
        if !supportKinds.isEmpty {
            let kinds = Set(exercise.equipmentVariations.flatMap { $0.supportEquipment }.map(\.kind))
            guard !kinds.isDisjoint(with: supportKinds) else { return false }
        }
        return true
    }

    private func matchesRatings(_ exercise: ExerciseModel) -> Bool {
        if let minimumRangeOfMotion, exercise.rangeOfMotion < minimumRangeOfMotion { return false }
        if let minimumStability, exercise.stability < minimumStability { return false }
        return true
    }

    private func matchesLibrary(_ exercise: ExerciseModel) -> Bool {
        switch library {
        case .all:      return true
        case .mine:     return !exercise.isSystemExercise
        case .official: return exercise.isSystemExercise
        }
    }

    private func matchesGym(_ exercise: ExerciseModel, availableEquipment: Set<EquipmentRef>) -> Bool {
        guard gymProfileId != nil else { return true }
        return Self.isPerformable(exercise, with: availableEquipment)
    }

    /// Performable when the exercise needs no equipment, or when at least one of its variations can
    /// be assembled *entirely* from what the gym has. Per-variation and all-or-nothing: half a
    /// variation is not a way to do the exercise.
    private static func isPerformable(_ exercise: ExerciseModel, with availableEquipment: Set<EquipmentRef>) -> Bool {
        if exercise.isBodyweight { return true }
        if exercise.equipmentVariations.isEmpty { return true }

        return exercise.equipmentVariations.contains { variation in
            let required = Set(variation.resistanceEquipment + variation.supportEquipment)
            return required.isSubset(of: availableEquipment)
        }
    }
}
