//
//  WorkoutSession.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import Foundation

struct WorkoutSessionModel: DataSyncModelProtocol, Equatable {
    let id: String
    let authorId: String
    var name: String
    let workoutTemplateId: String?
    let trainingProgramId: String?
    private(set) var dateCreated: Date
    private(set) var dateModified: Date
    private(set) var endedAt: Date?
    var notes: String?
    var exercises: [WorkoutExerciseModel]
    var deletedAt: Date?
    var isRestDay: Bool
    var likedByUserIds: [String]
    /// The author's training streak as of finishing this session, stamped by the finish path so
    /// followers — who cannot read the author's streak — can see it. Absent on older sessions.
    var streakCount: Int?

    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        workoutTemplateId: String? = nil,
        trainingProgramId: String? = nil,
        dateCreated: Date,
        dateModified: Date? = nil,
        endedAt: Date? = nil,
        notes: String? = nil,
        exercises: [WorkoutExerciseModel],
        deletedAt: Date? = nil,
        isRestDay: Bool = false,
        likedByUserIds: [String] = [],
        streakCount: Int? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.workoutTemplateId = workoutTemplateId
        self.trainingProgramId = trainingProgramId
        self.dateCreated = dateCreated
        self.dateModified = dateModified ?? dateCreated
        self.endedAt = endedAt
        self.notes = notes
        self.exercises = exercises
        self.deletedAt = deletedAt
        self.isRestDay = isRestDay
        self.likedByUserIds = likedByUserIds
        self.streakCount = streakCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name = "name"
        case workoutTemplateId = "workout_template_id"
        case trainingProgramId = "training_program_id"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case endedAt = "ended_at"
        case notes
        case exercises
        case deletedAt = "deleted_at"
        case isRestDay = "is_rest_day"
        case likedByUserIds = "liked_by_user_ids"
        case streakCount = "streak_count"
        case hidden
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    init(
        id: String = UUID().uuidString,
        authorId: String,
        template: WorkoutTemplateModel,
        notes: String? = nil,
        trainingProgramId: String? = nil,
        previousWorkoutSession: WorkoutSessionModel? = nil,
        gymProfile: GymProfileModel? = nil,
        unitPreferences: [String: ExerciseUnitPreference]? = nil,
        prefill: SessionPrefill = .previousValues,
        dateCreated: Date = .now
    ) {
        self.id = id
        self.authorId = authorId
        self.name = template.name
        self.workoutTemplateId = template.id
        self.trainingProgramId = trainingProgramId
        self.dateCreated = dateCreated
        self.dateModified = dateCreated
        self.endedAt = nil
        self.notes = notes
        self.deletedAt = nil
        self.isRestDay = false
        self.likedByUserIds = []
        self.exercises = template.exercises.enumerated().map { (idx, exerciseModel) in
            let mode = WorkoutSessionModel.trackingMode(for: exerciseModel.exercise)
            let targetCount = exerciseModel.setTargets.count
                        
            // Find matching exercise in previous workout session
            let previousExercise = previousWorkoutSession?.exercises.first(where: { $0.templateId == exerciseModel.exercise.id })
            let previousSets = previousExercise?.sets
                        
            // Estimate working weight and reps from previous workout
            let (estimatedWeight, estimatedReps) = WorkoutSessionModel.estimateWorkingWeightFromPrevious(previousSets: previousSets)
            
            // Create working sets (SetTargets) and populate with previous values if available
            var workingSets = WorkoutSessionModel.defaultSets(
                trackingMode: mode,
                authorId: authorId,
                targetCount: max(targetCount, 1),
                perSide: WorkoutSessionModel.isPerSide(exerciseModel.exercise)
            )
            
            // Fill the working sets the way the Initial Log Fill setting asks for: the
            // progression engine's suggestion where there is one, otherwise exactly what was
            // logged last time, and nothing at all for `.empty`.
            WorkingSetPrefill(
                prefill: prefill,
                previousSets: previousSets,
                authorId: authorId,
                exercise: exerciseModel.exercise,
                gymProfile: gymProfile,
                unitPreferences: unitPreferences
            ).apply(to: &workingSets)
            
            // Use the first working set's weight/reps for warmup calculation, or fall back to estimated values
            let firstWorkingSet = workingSets.first
            let workingWeightKg = firstWorkingSet?.weightKg ?? estimatedWeight
            let workingReps = firstWorkingSet?.reps ?? estimatedReps
                        
            // Generate warmup sets using working weight/reps
            let warmupSets = WorkoutSessionModel.generateWarmupSets(
                trackingMode: mode,
                authorId: authorId,
                workingWeightKg: workingWeightKg,
                workingReps: workingReps,
                setTargets: exerciseModel.setTargets,
                exercise: exerciseModel.exercise,
                gymProfile: gymProfile,
                unitPreferences: unitPreferences
            )
            
            // Prepend warmup sets to working sets
            let allSets = warmupSets + workingSets
            
            // Re-index all sets: warmup sets first, then working sets
            let reindexedSets = allSets.enumerated().map { index, set in
                WorkoutSetModel(
                    id: set.id,
                    authorId: set.authorId,
                    index: index + 1,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    durationSec: set.durationSec,
                    distanceMeters: set.distanceMeters,
                    rpe: set.rpe,
                    side: set.side,
                    isWarmup: set.isWarmup,
                    completedAt: set.completedAt,
                    dateCreated: set.dateCreated
                )
            }
            
            let imageName = Constants.exerciseImageName(for: exerciseModel.exercise.name)
            return WorkoutExerciseModel(
                id: UUID().uuidString,
                authorId: authorId,
                templateId: exerciseModel.exercise.id,
                name: exerciseModel.exercise.name,
                trackingMode: mode,
                index: idx + 1,
                notes: nil,
                imageName: imageName,
                sets: reindexedSets,
                setTargets: exerciseModel.setTargets,
                chosenVariationId: nil,
                equipmentVariations: exerciseModel.exercise.equipmentVariations
            )
        }
    }

    static func trackingMode(for exercise: ExerciseModel) -> TrackingMode {
        let metrics = Set(exercise.trackableMetrics)
        let weightMetrics: Set<TrackableExerciseMetric> = [
            .weight,
            .weightPerSide,
            .weightPerSidePersistent,
            .weightPerSideAssistance
        ]
        let timeMetrics: Set<TrackableExerciseMetric> = [.duration, .durationPerSide]
        let distanceMetrics: Set<TrackableExerciseMetric> = [.distanceShort, .distanceShortPerSide, .distanceLong]

        if !metrics.isDisjoint(with: weightMetrics) {
            return .weightReps
        }
        if !metrics.isDisjoint(with: distanceMetrics) {
            return .distanceTime
        }
        if !metrics.isDisjoint(with: timeMetrics) {
            return .timeOnly
        }
        return .repsOnly
    }

    /// Whether this exercise is worked one limb at a time, so each set is logged twice — once per
    /// side — and the two rows are the one set.
    ///
    /// Read off the metrics the exercise is tracked by, because that is the only field every
    /// exercise has. `laterality` would look like the obvious answer and is not: it is optional,
    /// user-created exercises almost always leave it empty, and only three of the seeded thirty-two
    /// set it, so it would silently classify nearly everything as two-sided.
    ///
    /// Only three of the five `*PerSide` metrics mean one side at a time. The weight ones do not:
    /// "per side" there means the plates on each end of a barbell, or one weight held in both
    /// hands, neither of which splits a set in two.
    static func isPerSide(_ exercise: ExerciseModel) -> Bool {
        let perSideMetrics: Set<TrackableExerciseMetric> = [
            .repsPerSide,
            .durationPerSide,
            .distanceShortPerSide
        ]
        return !Set(exercise.trackableMetrics).isDisjoint(with: perSideMetrics)
    }

    // Mutating methods for workout tracker
    mutating func updateExercises(_ exercises: [WorkoutExerciseModel]) {
        self.exercises = exercises
        self.dateModified = Date()
    }
    
    mutating func applyDeloadWeightReduction() {
        for iindex in exercises.indices {
            for jindex in exercises[iindex].sets.indices {
                if let weight = exercises[iindex].sets[jindex].weightKg {
                    exercises[iindex].sets[jindex].weightKg = weight * 0.65
                }
            }
        }
    }

    mutating func endSession(at date: Date) {
        self.endedAt = date
        self.dateModified = date
    }

    /// Moves a completed session to a different start time, keeping however long it took. Editing
    /// when a workout happened should not silently change how long it lasted.
    mutating func updateStart(_ date: Date) {
        let duration = endedAt?.timeIntervalSince(dateCreated)
        dateCreated = date
        if let duration {
            endedAt = date.addingTimeInterval(duration)
        }
        dateModified = Date()
    }

    /// Sets how long the session lasted, measured from its start. A non-positive duration would
    /// put the end before the beginning, so it is refused.
    mutating func updateDuration(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        endedAt = dateCreated.addingTimeInterval(seconds)
        dateModified = Date()
    }
    
    /// Estimates working weight and reps from previous workout sets
    /// Returns the weight and reps from the first non-warmup set, if available
    static func estimateWorkingWeightFromPrevious(
        previousSets: [WorkoutSetModel]?
    ) -> (weightKg: Double?, reps: Int?) {
        guard let previousSets = previousSets else {
            return (nil, nil)
        }
                
        // Find the first non-warmup set
        if let firstWorkingSet = previousSets.first(where: { !$0.isWarmup }) {
            return (firstWorkingSet.weightKg, firstWorkingSet.reps)
        }
        
        // If no working sets found, try to use the last set regardless of warmup status
        if let lastSet = previousSets.last {
            return (lastSet.weightKg, lastSet.reps)
        }
        
        return (nil, nil)
    }
    
    /// Rounds weight to match equipment constraints (pin-loaded/cable machines).
    /// Uses template resistance equipment. Optional preferred unit selects first range matching that unit.
    /// Returns rounded weight in kg, or original weight if no matching equipment found.
    @MainActor
    static func roundWeightToEquipmentIncrement(
        weightKg: Double,
        exercise: ExerciseModel,
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit? = nil
    ) -> Double {
        let firstVariation = exercise.equipmentVariations.first
        let refs = firstVariation?.resistanceEquipment ?? []
        return roundWeightToEquipmentIncrement(
            weightKg: weightKg,
            equipmentRefs: refs,
            gymProfile: gymProfile,
            preferredWeightUnit: preferredWeightUnit
        )
    }

    /// Rounds weight using the workout exercise's chosen variation resistance equipment.
    /// Uses first range whose unit matches preferredWeightUnit; if none, uses default or first active range.
    /// Returns rounded weight in kg, or original weight if no variation or equipment found.
    @MainActor
    static func roundWeightToEquipmentIncrement(
        weightKg: Double,
        workoutExercise: WorkoutExerciseModel,
        exerciseTemplate: ExerciseModel?,
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit?
    ) -> Double {
        let variation = exerciseTemplate?.equipmentVariations.first(where: { $0.id == workoutExercise.chosenVariationId })
            ?? exerciseTemplate?.equipmentVariations.first
        let refs = variation?.resistanceEquipment ?? []
        guard !refs.isEmpty else {
            return weightKg
        }
        return roundWeightToEquipmentIncrement(
            weightKg: weightKg,
            equipmentRefs: refs,
            gymProfile: gymProfile,
            preferredWeightUnit: preferredWeightUnit
        )
    }

    /// Internal: rounds weight using equipment refs, with gym fallback and optional preferred unit for range selection.
    @MainActor
    private static func roundWeightToEquipmentIncrement(
        weightKg: Double,
        equipmentRefs: [EquipmentRef],
        gymProfile: GymProfileModel?,
        preferredWeightUnit: ExerciseWeightUnit?
    ) -> Double {
        let gym = gymProfile ?? GymProfileModel(authorId: "")
        let fallbackGym = GymProfileModel(authorId: "")

        for equipmentRef in equipmentRefs {
            guard equipmentRef.kind == .pinLoadedMachine || equipmentRef.kind == .cableMachine else {
                continue
            }

            let weightRange: (any WeightRange)?

            switch equipmentRef.kind {
            case .pinLoadedMachine:
                let machine = gym.pinLoadedMachines.first(where: { $0.id == equipmentRef.equipmentId && $0.isActive })
                    ?? fallbackGym.pinLoadedMachines.first(where: { $0.id == equipmentRef.equipmentId })
                weightRange = machine.flatMap { resolveRange(for: $0, preferredWeightUnit: preferredWeightUnit) }
            case .cableMachine:
                let machine = gym.cableMachines.first(where: { $0.id == equipmentRef.equipmentId && $0.isActive })
                    ?? fallbackGym.cableMachines.first(where: { $0.id == equipmentRef.equipmentId })
                weightRange = machine.flatMap { resolveRange(for: $0, preferredWeightUnit: preferredWeightUnit) }
            default:
                weightRange = nil
            }

            guard let range = weightRange else {
                continue
            }

            let weightInEquipmentUnit = UnitConversion.convertWeight(weightKg, to: range.unit)
            let roundedInEquipmentUnit = (weightInEquipmentUnit / range.increment).rounded() * range.increment
            let clampedWeight = max(range.minWeight, min(range.maxWeight, roundedInEquipmentUnit))
            let roundedWeightKg = UnitConversion.convertWeightToKg(clampedWeight, from: range.unit)

            return roundedWeightKg
        }

        return weightKg
    }

    /// First range where unit matches preferredWeightUnit; else defaultRange or first active.
    @MainActor
    private static func resolveRange(for machine: CableMachine, preferredWeightUnit: ExerciseWeightUnit?) -> (any WeightRange)? {
        if let preferred = preferredWeightUnit,
           let match = machine.ranges.first(where: { $0.unit == preferred }) {
            return match
        }
        return machine.defaultRange ?? machine.ranges.first(where: { $0.isActive })
    }

    /// First range where unit matches preferredWeightUnit; else defaultRange or first active.
    @MainActor
    private static func resolveRange(for machine: PinLoadedMachine, preferredWeightUnit: ExerciseWeightUnit?) -> (any WeightRange)? {
        if let preferred = preferredWeightUnit,
           let match = machine.ranges.first(where: { $0.unit == preferred }) {
            return match
        }
        return machine.defaultRange ?? machine.ranges.first(where: { $0.isActive })
    }
    
    /// Rounds weight to user's preferred unit (0.5kg increments for kg, whole numbers for lbs)
    static func roundWeightToPreferredUnit(
        weightKg: Double?,
        preferredUnit: ExerciseWeightUnit
    ) -> Double? {
        guard let weightKg = weightKg else { return nil }
        
        // Convert to preferred unit
        let weightInPreferredUnit = UnitConversion.convertWeight(weightKg, to: preferredUnit)
        
        // Round based on unit
        let roundedWeight: Double
        switch preferredUnit {
        case .kilograms:
            // Round to nearest 0.5kg
            roundedWeight = round(weightInPreferredUnit * 2) / 2.0
        case .pounds:
            // Round to nearest whole number
            roundedWeight = round(weightInPreferredUnit)
        }
        
        // Convert back to kg for storage
        return UnitConversion.convertWeightToKg(roundedWeight, from: preferredUnit)
    }
    
    /// The empty sets an exercise starts a session with.
    ///
    /// `targetCount` is how many sets the user is being asked to do. For an exercise worked one
    /// limb at a time that is twice as many rows, left then right, because each side is filled in
    /// separately — but it is still that many sets, and everything that counts them says so.
    static func defaultSets(
        trackingMode: TrackingMode,
        authorId: String,
        targetCount: Int = 3,
        perSide: Bool = false
    ) -> [WorkoutSetModel] {
        let count = max(targetCount, 1)
        let sides: [SetSide?] = perSide ? SetSide.ordered.map { $0 } : [nil]
        var sets: [WorkoutSetModel] = []

        for _ in 0..<count {
            for side in sides {
                sets.append(
                    WorkoutSetModel(
                        id: UUID().uuidString,
                        authorId: authorId,
                        index: sets.count + 1,
                        reps: nil,
                        weightKg: nil,
                        durationSec: defaultDurationSec(for: trackingMode),
                        distanceMeters: defaultDistanceMeters(for: trackingMode),
                        rpe: nil,
                        side: side,
                        isWarmup: false,
                        completedAt: nil,
                        dateCreated: .now
                    )
                )
            }
        }

        return sets
    }

    /// Timed and distance work starts from a figure worth showing; weight and reps start empty.
    private static func defaultDurationSec(for trackingMode: TrackingMode) -> Int? {
        switch trackingMode {
        case .weightReps, .repsOnly: return nil
        case .timeOnly:              return 60
        case .distanceTime:          return 120
        }
    }

    private static func defaultDistanceMeters(for trackingMode: TrackingMode) -> Double? {
        trackingMode == .distanceTime ? 400 : nil
    }
    
    @MainActor
    static var mock: WorkoutSessionModel {
        mocks[0]
    }
    
    @MainActor
    static var mocks: [WorkoutSessionModel] {
        // Ensure mock sessions belong to the preview/mock user and are completed so they appear in history
        let uid = "mock_user_123"

        // Ten weeks of roughly four sessions a week, rotating through the available
        // templates, with sets filled in and progressively heavier over time. Three
        // sessions all dated "now" left the contribution chart, streaks and history
        // lists looking empty.
        let templates = WorkoutTemplateModel.mocks
        guard !templates.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekdayOffsets = [0, 2, 4, 5] // Mon/Wed/Fri/Sat-ish cadence
        var sessions: [WorkoutSessionModel] = []
        var counter = 0

        for weeksAgo in (0...9).reversed() {
            for (dayIndex, offset) in weekdayOffsets.enumerated() {
                // Skip the odd session so the history has realistic gaps.
                if (weeksAgo + dayIndex) % 7 == 3 { continue }

                let daysAgo = weeksAgo * 7 + (6 - offset)
                guard
                    let startOfDay = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                    let startedAt = calendar.date(byAdding: .hour, value: 7 + (dayIndex % 4) * 3, to: startOfDay),
                    startedAt <= .now
                else { continue }

                let template = templates[counter % templates.count]
                // Later sessions are heavier: ~1.5% per week of progression.
                let progression = 1.0 + (Double(9 - weeksAgo) * 0.015)
                let durationMinutes = 38 + (counter % 5) * 6

                var session = WorkoutSessionModel(
                    id: "session-\(counter + 1)",
                    authorId: uid,
                    template: template,
                    trainingProgramId: nil,
                    dateCreated: startedAt
                )
                session.fillMockSets(progression: progression, completedAt: startedAt)
                session.endSession(at: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)))
                session.likedByUserIds = Array(["user1", "user3", "user5"].prefix(counter % 4))
                // The streak the finish path would have stamped: one longer per session, reset by the gap above.
                session.streakCount = counter % 6 + 2
                sessions.append(session)
                counter += 1
            }
        }

        return sessions.reversed()
    }

    /// Fills every working set with a plausible completed result. Without this the mock
    /// sessions carried empty sets, so volume, 1RM and set-count analytics all read zero.
    @MainActor
    private mutating func fillMockSets(progression: Double, completedAt: Date) {
        for exerciseIndex in exercises.indices {
            let baseWeight = 30.0 + Double((exerciseIndex % 4) * 15)
            for setIndex in exercises[exerciseIndex].sets.indices {
                var set = exercises[exerciseIndex].sets[setIndex]
                if set.isWarmup {
                    set.reps = 10
                    set.weightKg = ((baseWeight * 0.5 * progression) / 2.5).rounded() * 2.5
                } else {
                    set.reps = 10 - setIndex
                    set.weightKg = ((baseWeight * progression) / 2.5).rounded() * 2.5
                    set.rpe = min(10, 7 + Double(setIndex))
                }
                set.completedAt = completedAt.addingTimeInterval(TimeInterval(180 * (setIndex + 1)))
                exercises[exerciseIndex].sets[setIndex] = set
            }
        }
    }

    // MARK: - Report moderation

    /// Set by the `onReportCreated` function once three people have reported this session; the
    /// rules stop the author changing it. Absent on almost every session.
    var hidden: Bool?

    /// Whether the feed leaves this session out for `readerId`. A hidden session is still shown
    /// to its author, who would otherwise see their own workout vanish without explanation.
    func isHidden(from readerId: String?) -> Bool {
        hidden == true && readerId != authorId
    }
}
