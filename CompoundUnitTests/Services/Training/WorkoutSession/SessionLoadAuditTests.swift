//
//  SessionLoadAuditTests.swift
//  CompoundUnitTests
//
//  How a session is loaded and what it keeps, after the 10 Oct 2026 audit
//  (docs/reviews/2026-10-10-equipment-variation-progression-audit.md): the variation an exercise
//  starts on, its unit, its warm-ups and drops, and the sets a finished session counts.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct SessionLoadAuditTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    nonisolated private static let bar = [EquipmentRef(kind: .loadableBar, id: "barbell")]
    nonisolated private static let dumbbells = [EquipmentRef(kind: .freeWeight, id: "dumbbells")]

    private func exercise(
        metrics: [TrackableExerciseMetric] = [.weight, .reps],
        variations: [EquipmentVariation] = [EquipmentVariation(id: "v-bar", resistanceEquipment: bar)],
        isAssisted: Bool = false
    ) -> ExerciseModel {
        ExerciseModel(
            id: "squat", authorId: "a", name: "Squat", trackableMetrics: isAssisted ? [.weightPerSideAssistance, .reps] : metrics,
            type: .compoundLower, laterality: .bilateral, muscleGroups: [.quads: .primary], isBodyweight: false,
            equipmentVariations: variations, rangeOfMotion: 4, stability: 4, bodyWeightContribution: 0, alternateNames: []
        )
    }

    private func template(_ exercise: ExerciseModel, targets: [SetTarget]? = nil, warmups: Int? = nil) -> WorkoutTemplateModel {
        var templateExercise = WorkoutTemplateExercise(
            exercise: exercise,
            setTargets: targets ?? (1...3).map { SetTarget(setNumber: $0, minReps: 8, maxReps: 12) },
            setRestTimers: false
        )
        templateExercise.warmupSetCount = warmups
        return WorkoutTemplateModel(id: "t", authorId: "a", name: "Legs", exercises: [templateExercise])
    }

    private func gym(barActive: Bool = true, dumbbellsActive: Bool = true) -> GymProfileModel {
        GymProfileModel(
            id: "gym-1", authorId: "a",
            freeWeights: [
                FreeWeights(id: "weight_plates", name: "Plates", needsColour: true, isPlates: true, range: [1.25, 2.5, 5, 10, 20].map {
                    FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: .kilograms, isActive: true)
                }, isActive: true),
                FreeWeights(id: "dumbbells", name: "Dumbbells", needsColour: false, range: [10, 20, 30].map {
                    FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: .pounds, isActive: true)
                }, isActive: dumbbellsActive)
            ],
            loadableBars: [LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
                LoadableBarsBaseWeight(id: "b20", baseWeight: 20, unit: .kilograms, isActive: true)
            ], isActive: barActive)],
            fixedWeightBars: [], bands: [], bodyWeights: [], cableMachines: [], plateLoadedMachines: [], pinLoadedMachines: []
        )
    }

    private func loggedSet(_ id: String, kg weight: Double?, reps: Int?, logged: Bool = true, warmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "a", index: 1, reps: reps, weightKg: weight, isWarmup: warmup, completedAt: logged ? start : nil, dateCreated: start)
    }

    // MARK: - The variation a session starts on

    @Test func lastTimesVariationInThisGymIsKept() {
        let variations = [
            EquipmentVariation(id: "v-db", resistanceEquipment: Self.dumbbells),
            EquipmentVariation(id: "v-bar", resistanceEquipment: Self.bar)
        ]
        let last = WorkoutExerciseModel(
            id: "e", authorId: "a", templateId: "squat", name: "Squat", trackingMode: .weightReps, index: 1, sets: [],
            chosenVariationId: "v-bar", equipmentVariations: variations
        )
        #expect(SessionLoadChoice.variationId(among: variations, previous: last, previousGymId: "gym-1", gym: gym()) == "v-bar")
        // In another gym, last time says nothing: the first this gym can do.
        #expect(SessionLoadChoice.variationId(among: variations, previous: last, previousGymId: "elsewhere", gym: gym()) == "v-db")
        // The first it can do, not the first listed.
        #expect(SessionLoadChoice.variationId(among: variations, previous: nil, previousGymId: nil, gym: gym(dumbbellsActive: false)) == "v-bar")
    }

    @Test func aDumbbellPressHoldsTwoWeights() {
        let press = exercise(metrics: [.weightPerSide, .reps])
        #expect(SessionLoadChoice.loadsPerSet(press) == 2)
        #expect(SessionLoadChoice.loadsPerSet(exercise()) == nil)
        var set = loggedSet("s", kg: 20, reps: 10)
        set.loadCount = 2
        #expect(set.volumeKg == 400)
    }

    @Test func aSessionStartsOnTheChosenEquipmentAndItsUnit() throws {
        let squat = exercise(variations: [EquipmentVariation(id: "v-db", resistanceEquipment: Self.dumbbells)])
        let session = WorkoutSessionModel(authorId: "a", template: template(squat), gymProfile: gym())
        let started = try #require(session.exercises.first)
        #expect(session.gymProfileId == "gym-1")
        #expect(started.chosenVariationId == "v-db")
        #expect(started.weightUnit == .pounds)
    }

    // MARK: - Warm-ups and drops

    /// 40 kg working sets on a 20 kg bar warm up on the bar and above it, never under it.
    @Test func warmUpsRoundToTheBar() {
        let warmups = WorkoutSessionModel.generateWarmupSets(
            trackingMode: .weightReps, authorId: "a", workingWeightKg: 40, workingReps: 5, setTargets: [],
            exercise: exercise(), gymProfile: gym(), weightUnit: .kilograms, resistanceEquipment: Self.bar
        )
        #expect(warmups.allSatisfy { ($0.weightKg ?? 0) >= 20 && ($0.weightKg ?? 0) < 40 })
    }

    @Test func assistedAndBodyweightWorkGetNoWarmUps() {
        let assisted = WorkoutSessionModel.generateWarmupSets(
            trackingMode: .weightReps, authorId: "a", workingWeightKg: -30, workingReps: 8, setTargets: [], exercise: exercise(isAssisted: true)
        )
        let bodyweight = WorkoutSessionModel.generateWarmupSets(
            trackingMode: .repsOnly, authorId: "a", workingWeightKg: nil, workingReps: 8, setTargets: []
        )
        #expect(assisted.isEmpty)
        #expect(bodyweight.isEmpty)
        // A plan's count still gets them, with more help than the work.
        let planned = WorkoutSessionModel.generateWarmupSets(
            trackingMode: .weightReps, authorId: "a", workingWeightKg: -30, workingReps: 8, setTargets: [], count: 2
        )
        #expect(planned.count == 2 && planned.allSatisfy { ($0.weightKg ?? 0) < -30 })
    }

    /// A planned drop steps down to a dumbbell the rack has.
    @Test func plannedDropsLandOnTheEquipment() {
        let set = loggedSet("s", kg: 30, reps: 8, logged: false)
        let rack = WeightRoundingRule(
            step: WeightStep(kind: .list([10, 20, 30]), chip: nil, baseWeight: nil, plates: []), unit: .kilograms, preferredUnit: .kilograms
        )
        let planned = WorkoutSessionModel.applyingSetPlan(
            to: [set], setTargets: [SetTarget(setNumber: 1, setType: .drop, dropCount: 2, dropStepPercent: 20)],
            authorId: "a", rounding: rack
        )
        #expect(planned.map(\.weightKg) == [30, 20, 10])
    }

    @Test func aTargetRIRIsTheSetsStartingEffort() {
        let sets = WorkoutSessionModel.defaultSets(
            trackingMode: .weightReps, authorId: "a", targetCount: 2,
            setTargets: [SetTarget(setNumber: 1, minReps: 8, maxReps: 12, rirTarget: 2), SetTarget(setNumber: 2, setType: .amrap)]
        )
        #expect(sets.map(\.rpe) == [8, 10])
    }

    // MARK: - What a finished session keeps

    @Test func finishingDropsTheSetsNeverLogged() {
        var session = WorkoutSessionModel(id: "s", authorId: "a", name: "W", dateCreated: start, exercises: [
            WorkoutExerciseModel(
                id: "e1", authorId: "a", templateId: "squat", name: "Squat", trackingMode: .weightReps, index: 1,
                sets: [loggedSet("a", kg: 100, reps: 5), loggedSet("b", kg: 100, reps: 5, logged: false)],
                weightUnit: .pounds, loadsPerSet: 2
            ),
            WorkoutExerciseModel(
                id: "e2", authorId: "a", templateId: "curl", name: "Curl", trackingMode: .weightReps, index: 2,
                sets: [loggedSet("c", kg: 10, reps: 10, logged: false)], setTargets: [SetTarget(setNumber: 1)]
            )
        ])
        session.dropUnloggedSets()
        #expect(session.exercises.count == 2)
        #expect(session.exercises[0].sets.map(\.id) == ["a"])
        #expect(session.exercises[0].sets[0].weightUnit == .pounds)
        #expect(session.exercises[0].sets[0].loadCount == 2)
        #expect(session.doneExercises.map(\.id) == ["e1"])
        #expect(session.loggedSetCount == 1)
        #expect(session.loggedVolumeKg == 1000)
        #expect(session.authorWeightUnit == .pounds)
    }

    // MARK: - Counting

    /// A right side after an easy left is worth its own credit, not nothing.
    @Test func aHardRightAfterAnEasyLeftCounts() {
        func side(_ id: String, _ side: SetSide, rpe: Double) -> WorkoutSetModel {
            WorkoutSetModel(id: id, authorId: "a", index: 1, reps: 10, weightKg: 20, rpe: rpe, side: side, isWarmup: false, completedAt: start, dateCreated: start)
        }
        let exercise = WorkoutExerciseModel(
            id: "e", authorId: "a", templateId: "row", name: "Row", trackingMode: .weightReps, index: 1,
            sets: [side("1l", .left, rpe: 8), side("1r", .right, rpe: 5), side("2l", .left, rpe: 5), side("2r", .right, rpe: 8)]
        )
        #expect(MuscleVolume.hardSets(exercise) == 2)
    }

    /// No reps, or none done, is no one-rep max: a failed attempt corrected to 0 is not a single.
    @Test func aSetWithNoRepsHasNoEstimate() {
        #expect(ExerciseOneRMAggregator.estimated1RM(of: loggedSet("s", kg: 140, reps: 0)) == nil)
        #expect(ExerciseOneRMAggregator.estimated1RM(of: loggedSet("s", kg: 140, reps: nil)) == nil)
    }

    /// Exercise stats count a `both` row twice and a left/right pair once, as the session does.
    @Test func exerciseStatsAgreeWithTheSession() {
        let both = WorkoutSetModel(id: "b", authorId: "a", index: 1, reps: 10, weightKg: 30, side: .both, isWarmup: false, completedAt: start, dateCreated: start)
        let session = WorkoutSessionModel(id: "s", authorId: "a", name: "W", dateCreated: start, endedAt: start, exercises: [
            WorkoutExerciseModel(id: "e", authorId: "a", templateId: "row", name: "Row", trackingMode: .weightReps, index: 1, sets: [both])
        ])
        let stats = ExerciseModelDetailStats.make(from: [session], templateId: "row")
        #expect(stats.totalVolumeKg == 600)
        #expect(stats.totalSets == 1)
    }

    /// Strava gets sets of their own: a myo set with three mini-sets is one set.
    @Test func stravaLeavesOutPieces() {
        let parent = loggedSet("p", kg: 50, reps: 12)
        var mini = loggedSet("m", kg: 50, reps: 4)
        mini.parentSetId = "p"
        #expect(StravaStrengthFile.uploadedRows([parent, mini, mini]).map(\.id) == ["p"])
    }

    // MARK: - Decoding

    /// An exercise stored inside a template with a field this build cannot read keeps the rest.
    @Test func anExerciseWithAnUnknownFieldStillDecodes() throws {
        let json = #"""
        {"id":"x","name":"Press","trackable_metrics":["weight","futureMetric"],"type":"futureType",
         "equipment_variations":[{"id":"v","resistance_equipment":[{"kind":"futureKind","id":"z"},{"kind":"loadableBar","id":"barbell"}],"support_equipment":[]}]}
        """#
        let exercise = try JSONDecoder().decode(ExerciseModel.self, from: Data(json.utf8))
        #expect(exercise.trackableMetrics == [.weight])
        #expect(exercise.type == nil)
        #expect(exercise.equipmentVariations.first?.resistanceEquipment == [EquipmentRef(kind: .loadableBar, id: "barbell")])
    }

    /// Every equipment ref in the seeded library names something the catalogue has.
    @Test func everySeedRefResolves() {
        let catalogue = Set(GymProfileModel(authorId: "a").allEquipment.map(\.ref))
        let missing = PrebuiltSeedData.exercises.flatMap { exercise in
            exercise.equipmentVariations.flatMap { $0.resistanceEquipment + $0.supportEquipment }
                .filter { !catalogue.contains($0) }
                .map { "\(exercise.name): \($0.equipmentId)" }
        }
        #expect(missing.isEmpty, "\(missing)")
    }

    /// A removed custom machine is named for what happened to it, not by its generated id.
    @Test func aRemovedMachineIsNamed() {
        #expect(EquipmentRef(kind: .cableMachine, id: UUID().uuidString).fallbackName == String(localized: "Removed equipment"))
        #expect(EquipmentRef(kind: .cableMachine, id: "lat_pulldown").fallbackName == "lat_pulldown")
    }

    /// Two warm-ups last time, three today: today's third has no "last time".
    @Test func warmUpsMatchByTheirPlace() {
        func warm(_ id: String, _ index: Int) -> WorkoutSetModel {
            WorkoutSetModel(id: id, authorId: "a", index: index, reps: 5, weightKg: Double(index * 20), isWarmup: true, dateCreated: start)
        }
        let working = WorkoutSetModel(id: "lw", authorId: "a", index: 3, reps: 5, weightKg: 100, isWarmup: false, dateCreated: start)
        let last = WorkoutExerciseModel(id: "l", authorId: "a", templateId: "t", name: "S", trackingMode: .weightReps, index: 1, sets: [warm("l1", 1), warm("l2", 2), working])
        let today = WorkoutExerciseModel(id: "t", authorId: "a", templateId: "t", name: "S", trackingMode: .weightReps, index: 1, sets: [warm("t1", 1), warm("t2", 2), warm("t3", 3)])
        #expect(last.matchingSet(for: today.sets[1], in: today)?.id == "l2")
        #expect(last.matchingSet(for: today.sets[2], in: today) == nil)
    }
}
