//
//  Samples+Library.swift
//  CompoundUnitTests
//
//  The fixed training-library samples behind contracts/firestore/{exercise_model,
//  exercise_settings,workout_template,workout_template_exercise,workout_settings}. See
//  FirestoreContractTests.swift.
//

import Foundation
@testable import Compound

extension Samples {
    static let fullExerciseModel = ExerciseModel(
        id: "exercise_model_contract_full",
        authorId: "user_contract_full",
        name: "Paused Bench Press",
        description: "Two seconds still on the chest.",
        imageURL: "https://example.com/paused-bench.jpg",
        trackableMetrics: [.reps, .weight],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: [.chest: .primary, .triceps: .secondary, .frontDelts: .secondary],
        isBodyweight: false,
        equipmentVariations: [fullEquipmentVariation],
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: ["Pause Bench", "Competition Bench"],
        isSystemExercise: false,
        dateCreated: date("2026-09-01T10:00:00.125Z"),
        dateModified: date("2026-10-01T11:30:00.500Z"),
        clickCount: 3,
        bookmarkCount: 1,
        favouriteCount: 2
    )

    static let minimalExerciseModel = ExerciseModel(
        id: "exercise_model_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Plank",
        trackableMetrics: [],
        type: nil,
        laterality: nil,
        muscleGroups: [:],
        isBodyweight: true,
        rangeOfMotion: 1,
        stability: 2,
        bodyWeightContribution: 100,
        alternateNames: [],
        dateCreated: date("2026-09-02T10:00:00.000Z"),
        dateModified: date("2026-09-02T10:00:00.000Z"),
        clickCount: nil,
        bookmarkCount: nil,
        favouriteCount: nil
    )

    static let fullExerciseSettings: ExerciseSettingsModel = {
        var settings = ExerciseSettingsModel(id: "exercise_model_contract_full", authorId: "user_contract_full")
        settings.note = "Grip one finger wider"
        settings.restDurationOverride = 150
        return settings
    }()

    static let minimalExerciseSettings = ExerciseSettingsModel(id: "plank", authorId: "user_contract_minimal")

    static let fullTemplateExercise = WorkoutTemplateExercise(
        id: "template_exercise_contract_full",
        exercise: fullExerciseModel,
        setTargets: [fullSetTarget],
        setRestTimers: true,
        notes: "Pause every rep",
        warmupSetCount: 2,
        restSeconds: 150,
        substituteExerciseIds: ["dumbbell_bench_press"],
        supersetGroupId: "superset_contract",
        linkURL: "https://example.com/paused-bench",
        setTargetsByMicrocycle: [MicrocycleSetTargets(fromMicrocycle: 3, setTargets: [minimalSetTarget])]
    )

    static let minimalTemplateExercise = WorkoutTemplateExercise(
        id: "template_exercise_contract_minimal",
        exercise: minimalExerciseModel,
        setTargets: [minimalSetTarget],
        setRestTimers: false
    )

    static let fullWorkoutTemplate = WorkoutTemplateModel(
        id: "template_contract_full",
        authorId: "user_contract_full",
        name: "Push A",
        description: "Bench first, then shoulders",
        gymProfileId: "gym_contract",
        imageURL: "https://example.com/push-a.jpg",
        dateCreated: date("2026-08-01T09:00:00.250Z"),
        dateModified: date("2026-10-02T09:15:00.750Z"),
        exercises: [fullTemplateExercise, minimalTemplateExercise]
    )

    static let minimalWorkoutTemplate = WorkoutTemplateModel(
        id: "template_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Empty",
        dateCreated: date("2026-08-02T09:00:00.000Z"),
        dateModified: date("2026-08-02T09:00:00.000Z")
    )

    static let fullWorkoutSettings: WorkoutSettings = {
        var settings = WorkoutSettings(authorId: "user_contract_full")
        settings.previousWorkoutReference = .workoutsInMesocycle
        settings.propagateChanges = false
        settings.rirTracking = true
        settings.supersetAutoScroll = false
        settings.exerciseAutoNext = false
        settings.keepAlive = false
        settings.showWorkoutTimer = false
        settings.showBodyweightContribution = true
        settings.showOnLockScreen = false
        settings.setPlanning = true
        settings.addSmartWarmUps = false
        settings.smartProgressionApplyInSession = true
        settings.smartProgressionInitialLogFill = .previousValues
        settings.smartProgressionAdjustmentMode = .repsFirst
        settings.amrapRaisesTarget = false
        settings.amrapAddsWeightAtTarget = 15
        settings.amrapAddsWeight = false
        settings.useRestTimers = false
        settings.restAfterLastWarmUp = false
        settings.restBetweenExercises = false
        settings.restBetweenSideSets = true
        settings.supersetTransitionRestSeconds = 20
        settings.intraSetRestSeconds = 12
        settings.intraSetRestMyoSeconds = 10
        settings.intraSetRestPauseSeconds = 25
        settings.intraSetRestClusterSeconds = 18
        settings.restTimerPlaySound = false
        settings.restTimerVibrate = false
        settings.warmUpRestScaling = 0.625
        settings.betweenExercisesRestScaling = 1.25
        settings.sideSetRestScaling = 0.375
        settings.restDurationsByExerciseType = ["compoundUpper": 180, "isolationUpper": 75]
        settings.defaultRestDurationSeconds = 120
        return settings
    }()

    /// The defaults, but for `betweenExercisesRestScaling`: its default 1.0 would be recorded as
    /// the integer 1, and the contract keeps number types.
    static let minimalWorkoutSettings: WorkoutSettings = {
        var settings = WorkoutSettings(authorId: "user_contract_minimal")
        settings.betweenExercisesRestScaling = 1.5
        return settings
    }()
}
