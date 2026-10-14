//
//  WorkoutExerciseModel.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import Foundation

struct WorkoutExerciseModel: Identifiable, DataSyncModelProtocol, Equatable {
    let id: String
    let authorId: String
    var templateId: String
    var name: String
    var trackingMode: TrackingMode
    var index: Int
    var notes: String?
    var imageName: String?
    var sets: [WorkoutSetModel] {
        didSet { stampMachineBase() }
    }
    var setTargets: [SetTarget]
    var chosenVariationId: String?
    var equipmentVariations: [EquipmentVariation]
    var supersetGroupId: String?
    /// The plan's notes for this exercise, copied from the template. The user's own are `notes`.
    var planNotes: String?
    /// The plan's exercise this one was started from (`WorkoutTemplateExercise.id`), so its
    /// mesocycle note can be written back to that slot of that day. Absent on exercises added
    /// mid-workout and on sessions from before it was stored.
    var planSlotId: String?
    /// The plan's rest for this exercise, ahead of the exercise and global rest settings.
    var restSeconds: Int?
    /// The plan's video or reference link.
    var linkURL: String?
    /// Exercise ids the plan offers in this one's place.
    var substituteExerciseIds: [String]
    /// The unit this exercise's weights are entered in for the session: the user's own choice for
    /// the exercise, else the unit the equipment is labelled in, else the app-wide unit
    /// (`SessionWeightUnit`). `nil` on sessions from before it was stored, which read the
    /// exercise's preference as they always did.
    var weightUnit: ExerciseWeightUnit?
    /// How many of the weight one set lifts: 2 for a dumbbell in each hand, from the exercise's
    /// `weightPerSide` metric. Stamped on each set as it is logged (`WorkoutSetModel.loadCount`).
    var loadsPerSet: Int?
    /// The machine base its weights are entered without, in kg: the active variation's
    /// plate-loaded machine, when it is set to enter plates only (`SessionLoadChoice.machineBaseKg`).
    /// Every set not yet logged carries it; a logged set keeps the one it was logged with.
    var machineBaseKg: Double? {
        didSet { stampMachineBase() }
    }

    init(
        id: String,
        authorId: String,
        templateId: String,
        name: String,
        trackingMode: TrackingMode,
        index: Int,
        notes: String? = nil,
        imageName: String? = nil,
        sets: [WorkoutSetModel],
        setTargets: [SetTarget] = [],
        chosenVariationId: String? = nil,
        equipmentVariations: [EquipmentVariation] = [],
        supersetGroupId: String? = nil,
        planNotes: String? = nil,
        planSlotId: String? = nil,
        restSeconds: Int? = nil,
        linkURL: String? = nil,
        substituteExerciseIds: [String] = [],
        weightUnit: ExerciseWeightUnit? = nil,
        loadsPerSet: Int? = nil,
        machineBaseKg: Double? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.templateId = templateId
        self.name = name
        self.trackingMode = trackingMode
        self.index = index
        self.notes = notes
        self.imageName = imageName
        self.sets = sets
        self.setTargets = setTargets
        self.chosenVariationId = chosenVariationId
        self.equipmentVariations = equipmentVariations
        self.supersetGroupId = supersetGroupId
        self.planNotes = planNotes
        self.planSlotId = planSlotId
        self.restSeconds = restSeconds
        self.linkURL = linkURL
        self.substituteExerciseIds = substituteExerciseIds
        self.weightUnit = weightUnit
        self.loadsPerSet = loadsPerSet
        self.machineBaseKg = machineBaseKg
        stampMachineBase()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case templateId = "template_id"
        case name
        case trackingMode = "tracking_mode"
        case index
        case notes
        case imageName = "image_name"
        case sets
        case setTargets = "set_targets"
        case chosenVariationId = "chosen_variation_id"
        case equipmentVariations = "equipment_variations"
        case supersetGroupId = "superset_group_id"
        case planNotes = "plan_notes"
        case planSlotId = "plan_slot_id"
        case restSeconds = "rest_seconds"
        case linkURL = "link_url"
        case substituteExerciseIds = "substitute_exercise_ids"
        case weightUnit = "weight_unit"
        case loadsPerSet = "loads_per_set"
        case machineBaseKg = "machine_base_kg"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        templateId = try container.decode(String.self, forKey: .templateId)
        name = try container.decode(String.self, forKey: .name)
        trackingMode = try container.decode(TrackingMode.self, forKey: .trackingMode)
        index = try container.decode(Int.self, forKey: .index)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        sets = try container.decode([WorkoutSetModel].self, forKey: .sets)
        setTargets = try container.decodeIfPresent([SetTarget].self, forKey: .setTargets) ?? []
        chosenVariationId = try container.decodeIfPresent(String.self, forKey: .chosenVariationId)
        // Element by element: a variation naming equipment a later build added must not cost the
        // whole logged session.
        equipmentVariations = container.decodeLossyArray(EquipmentVariation.self, forKey: .equipmentVariations) ?? []
        supersetGroupId = try container.decodeIfPresent(String.self, forKey: .supersetGroupId)
        planNotes = try container.decodeIfPresent(String.self, forKey: .planNotes)
        planSlotId = try container.decodeIfPresent(String.self, forKey: .planSlotId)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        substituteExerciseIds = try container.decodeIfPresent([String].self, forKey: .substituteExerciseIds) ?? []
        weightUnit = (try? container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .weightUnit)) ?? nil
        loadsPerSet = (try? container.decodeIfPresent(Int.self, forKey: .loadsPerSet)) ?? nil
        machineBaseKg = (try? container.decodeIfPresent(Double.self, forKey: .machineBaseKg)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(name, forKey: .name)
        try container.encode(trackingMode, forKey: .trackingMode)
        try container.encode(index, forKey: .index)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encode(sets, forKey: .sets)
        try container.encode(setTargets, forKey: .setTargets)
        try container.encodeIfPresent(chosenVariationId, forKey: .chosenVariationId)
        try container.encode(equipmentVariations, forKey: .equipmentVariations)
        try container.encodeIfPresent(supersetGroupId, forKey: .supersetGroupId)
        try container.encodeIfPresent(planNotes, forKey: .planNotes)
        try container.encodeIfPresent(planSlotId, forKey: .planSlotId)
        try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
        if !substituteExerciseIds.isEmpty {
            try container.encode(substituteExerciseIds, forKey: .substituteExerciseIds)
        }
        try container.encodeIfPresent(weightUnit, forKey: .weightUnit)
        try container.encodeIfPresent(loadsPerSet, forKey: .loadsPerSet)
        try container.encodeIfPresent(machineBaseKg, forKey: .machineBaseKg)
    }

    /// Sets still to do take the exercise's machine base, so a weight entered or shown on them
    /// leaves it out; logged sets keep theirs.
    private mutating func stampMachineBase() {
        for index in sets.indices where sets[index].completedAt == nil && sets[index].machineBaseKg != machineBaseKg {
            sets[index].machineBaseKg = machineBaseKg
        }
    }

    /// The variation the session is on: the chosen one, else the first.
    var activeVariation: EquipmentVariation? {
        equipmentVariations.first { $0.id == chosenVariationId } ?? equipmentVariations.first
    }

    /// Stamps a set as it is logged with what it cannot know itself: the unit it was entered in
    /// and how many of the weight it lifted.
    func stamping(_ set: WorkoutSetModel) -> WorkoutSetModel {
        var set = set
        set.weightUnit = set.weightUnit ?? weightUnit
        set.loadCount = set.loadCount ?? loadsPerSet
        return set
    }

    /// How many working sets are logged, with a left/right pair counted as the one set it is.
    /// See `WorkoutSetPairing`.
    var completedSetsCount: Int {
        loggedSetCount
    }

    static var mock: WorkoutExerciseModel {
        mocks.first ?? userMocks[0]
    }

    /// Session exercises built from the seeded library, the same way `WorkoutSessionModel`
    /// builds them from a template: the seeded exercise's id as `templateId`, its real name,
    /// the tracking mode derived from its metrics, and the image resolved through `Constants`.
    /// Hand-written names like "Bench Press" matched nothing in the image map, so every mock
    /// session exercise rendered without artwork.
    static var mocks: [WorkoutExerciseModel] {
        ExerciseModel.mocks.prefix(10).enumerated().map { index, exercise in
            mock(exercise: exercise, index: index)
        }
    }

    /// The same, for the mock user's own exercises — these cover the duration-tracked and
    /// reps-only modes the seeded library does not.
    static var userMocks: [WorkoutExerciseModel] {
        ExerciseModel.userMocks.enumerated().map { index, exercise in
            mock(exercise: exercise, index: index)
        }
    }

    static func mock(exercise: ExerciseModel, index: Int) -> WorkoutExerciseModel {
        let trackingMode = WorkoutSessionModel.trackingMode(for: exercise)
        return WorkoutExerciseModel(
            id: "workout-exercise-\(exercise.id)",
            authorId: "mock_user_123",
            templateId: exercise.id,
            name: exercise.name,
            trackingMode: trackingMode,
            index: index + 1,
            notes: nil,
            imageName: Constants.exerciseImageName(for: exercise.name),
            sets: mockSets(exerciseId: exercise.id, trackingMode: trackingMode, index: index),
            setTargets: [],
            equipmentVariations: exercise.equipmentVariations
        )
    }

    /// Three completed working sets, filled in for whichever metrics the exercise tracks —
    /// a duration-tracked exercise carrying a weight and no time reads as broken data.
    private static func mockSets(exerciseId: String, trackingMode: TrackingMode, index: Int) -> [WorkoutSetModel] {
        let baseWeight: Double = 40 + Double(index % 5) * 12.5
        let tracksReps = trackingMode == .weightReps || trackingMode == .repsOnly
        let tracksWeight = trackingMode == .weightReps
        let tracksDuration = trackingMode == .timeOnly || trackingMode == .distanceTime
        let tracksDistance = trackingMode == .distanceTime

        return (0..<3).map { setIndex -> WorkoutSetModel in
            let reps: Int? = tracksReps ? 10 - setIndex : nil
            let weightKg: Double? = tracksWeight ? baseWeight + Double(setIndex) * 2.5 : nil
            let durationSec: Int? = tracksDuration ? 45 + setIndex * 15 : nil
            let distanceMeters: Double? = tracksDistance ? Double(setIndex + 1) * 400 : nil
            let completedAt = Date().addingTimeInterval(Double(setIndex - 3) * 300)
            let dateCreated = Date().addingTimeInterval(Double(setIndex - 4) * 300)

            return WorkoutSetModel(
                id: "\(exerciseId)-set-\(setIndex + 1)",
                authorId: "mock_user_123",
                index: setIndex + 1,
                reps: reps,
                weightKg: weightKg,
                durationSec: durationSec,
                distanceMeters: distanceMeters,
                rpe: 7 + Double(setIndex) * 0.5,
                isWarmup: false,
                completedAt: completedAt,
                dateCreated: dateCreated
            )
        }
    }
}

extension WorkoutExerciseModel {

    /// The image to show: the one stored with the session, else the library exercise's. A session
    /// keeps the image its exercises had when it began, so one logged before an exercise was
    /// bundled with artwork, or repointed at a bundled exercise since, stored none.
    ///
    /// The library is an autoclosure because reading it is a SwiftData fetch and a decode of every
    /// exercise: a stored image returns before it is ever evaluated.
    func imageName(in library: @autoclosure () -> [ExerciseModel]) -> String? {
        if let imageName, !imageName.isEmpty { return imageName }
        return libraryModel(in: library()).flatMap { Constants.exerciseImageName(for: $0) }
    }

    /// `preference` (the template's units) with this exercise's own weight unit in place, when it
    /// has one: an exercise switched to pounds mid-workout keeps pounds.
    func units(_ preference: ExerciseUnitPreference) -> ExerciseUnitPreference {
        var units = preference
        units.weightUnit = weightUnit ?? preference.weightUnit
        return units
    }

    /// One more set — which is two rows for an exercise whose sides are split, so the user is
    /// never handed a left with no right to follow it.
    func addingSet(authorId: String, now: Date = Date()) -> WorkoutExerciseModel {
        var exercise = self
        // One past the highest index, not one past the count. Deleting a set does not renumber the
        // rest, so after deleting any set but the last, the count no longer reaches the top index
        // and this handed the new set an index another set already held. Warm-up sets share the
        // same numbering, which makes it easier still to hit.
        var nextIndex = (sets.map(\.index).max() ?? 0) + 1
        for side in sidesPerSet {
            // Carry forward the figures of the last set on the same side, so a left set copies the
            // left arm's weight rather than the right one's. Not a drop's: it is lighter than the set.
            let ownSets = sets.filter { !$0.isSubSet }
            let lastSet = ownSets.last(where: { side == nil || $0.side == side }) ?? ownSets.last
            exercise.sets.append(WorkoutSetModel(
                id: UUID().uuidString,
                authorId: authorId,
                index: nextIndex,
                reps: lastSet?.reps,
                weightKg: lastSet?.weightKg,
                durationSec: lastSet?.durationSec,
                distanceMeters: lastSet?.distanceMeters,
                rpe: lastSet?.rpe,
                side: side,
                bands: lastSet?.bands,
                isWarmup: false,
                completedAt: nil,
                dateCreated: now
            ))
            nextIndex += 1
        }
        return exercise
    }

    /// The library exercise this one was made from, by `templateId`.
    func libraryModel(in library: [ExerciseModel]) -> ExerciseModel? {
        library.first { $0.id == templateId }
    }
}
