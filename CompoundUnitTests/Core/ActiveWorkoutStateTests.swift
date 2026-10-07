//
//  ActiveWorkoutStateTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The active-workout screen's rules: which row is current, the progress header, the
/// progression reason, where the rest timer sits, the log button, and loads rounded to plates.
@MainActor
struct ActiveWorkoutStateTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        _ id: String,
        reps: Int? = 5,
        weightKg: Double? = 100,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        side: SetSide? = nil,
        doneAt offset: TimeInterval? = nil
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            rpe: rpe,
            side: side,
            isWarmup: isWarmup,
            completedAt: offset.map { start.addingTimeInterval($0) },
            dateCreated: start
        )
    }

    private func exercise(_ id: String, name: String = "Squat", sets: [WorkoutSetModel], targets: [SetTarget] = []) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(id)",
            name: name,
            trackingMode: .weightReps,
            index: 1,
            sets: sets,
            setTargets: targets
        )
    }

    // MARK: - Row states

    @Test("Test The First Set Not Logged Is Current, Warm-Ups Included")
    func testRowStates() {
        let squat = exercise("e1", sets: [
            set("w1", isWarmup: true, doneAt: 0),
            set("w2", isWarmup: true),
            set("s1"),
            set("s2")
        ])

        #expect(ActiveWorkout.rowState(of: squat.sets[0], in: squat) == .done)
        #expect(ActiveWorkout.rowState(of: squat.sets[1], in: squat) == .current)
        #expect(ActiveWorkout.rowState(of: squat.sets[2], in: squat) == .upcoming)
        #expect(ActiveWorkout.rowState(of: squat.sets[3], in: squat) == .upcoming)
    }

    /// A set logged out of order is done, and the earliest open set stays current.
    @Test("Test A Skipped Set Stays Current")
    func testSkippedSetStaysCurrent() {
        let squat = exercise("e1", sets: [set("s1"), set("s2", doneAt: 0), set("s3")])

        #expect(ActiveWorkout.rowState(of: squat.sets[0], in: squat) == .current)
        #expect(ActiveWorkout.rowState(of: squat.sets[1], in: squat) == .done)
        #expect(ActiveWorkout.rowState(of: squat.sets[2], in: squat) == .upcoming)
    }

    @Test("Test The Header Counts Working Sets Only, A Pair Once")
    func testProgress() {
        let exercises = [
            exercise("e1", sets: [set("w", isWarmup: true, doneAt: 0), set("s1", doneAt: 1), set("s2")]),
            exercise("e2", sets: [set("l", side: .left, doneAt: 2), set("r", side: .right)])
        ]

        let progress = ActiveWorkout.progress(of: exercises, currentIndex: 1)

        #expect(progress == .init(doneWorkingSets: 1, totalWorkingSets: 3, exerciseNumber: 2, exerciseCount: 2))
    }

    // MARK: - Progression reason

    @Test("Test The Reason Says What Changed And Why")
    func testProgressionReason() {
        let last = exercise("e0", sets: [set("a", reps: 5, doneAt: 0), set("b", reps: 6, doneAt: 1)])
        let heavier = ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 102.5, reps: 5)])

        #expect(
            ActiveWorkout.progressionReason(suggestion: heavier, last: last, unit: .kilograms)
                == "+2.5 kg today. You hit 5 reps on every working set last time."
        )

        let moreReps = ProgressionSuggestion(rationale: .addReps, sets: [SuggestedSet(weightKg: 100, reps: 6)])
        #expect(ActiveWorkout.progressionReason(suggestion: moreReps, last: last, unit: .kilograms) == "+1 rep today, at the same weight as last time.")
    }

    /// Typed over, the sentence would describe numbers that are no longer on screen.
    @Test("Test The Reason Goes Once The Set Is Edited")
    func testProgressionReasonHiddenAfterEdit() {
        let last = exercise("e0", sets: [set("a", reps: 5, doneAt: 0)])
        let heavier = ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 102.5, reps: 5)])
        let asSuggested = exercise("e1", sets: [set("w", weightKg: 60, isWarmup: true), set("a", reps: 5, weightKg: 102.5)])
        let edited = exercise("e1", sets: [set("a", reps: 5, weightKg: 100)])

        #expect(ActiveWorkout.progressionReason(suggestion: heavier, planned: asSuggested, last: last, unit: .kilograms) != nil)
        #expect(ActiveWorkout.progressionReason(suggestion: heavier, planned: edited, last: last, unit: .kilograms) == nil)
    }

    @Test("Test No Reason Is Given When Nothing Changed")
    func testProgressionReasonHidden() {
        let last = exercise("e0", sets: [set("a", doneAt: 0)])
        let hold = ProgressionSuggestion(rationale: .hold, sets: [SuggestedSet(weightKg: 100, reps: 5)])
        let roundedAway = ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 100, reps: 5)])

        #expect(ActiveWorkout.progressionReason(suggestion: hold, last: last, unit: .kilograms) == nil)
        #expect(ActiveWorkout.progressionReason(suggestion: roundedAway, last: last, unit: .kilograms) == nil)
        #expect(ActiveWorkout.progressionReason(suggestion: .noHistory(setCount: 1), last: last, unit: .kilograms) == nil)
        #expect(ActiveWorkout.progressionReason(suggestion: hold, last: nil, unit: .kilograms) == nil)
    }

    // MARK: - Rest timer

    @Test("Test The Rest Timer Sits Under The Working Set It Follows")
    func testRestUnderWorkingSet() {
        let squat = exercise("e1", sets: [set("s1", doneAt: 0), set("s2", doneAt: 60), set("s3")])
        let rested = ActiveWorkout.latestCompletedSet(in: [squat])

        #expect(rested?.id == "s2")
        #expect(ActiveWorkout.restAnchor(in: squat, restedSet: rested, restStartedAt: start.addingTimeInterval(61)) == .below(setId: "s2"))
    }

    /// A logged warm-up is hidden, and another exercise's set is not in this table.
    @Test("Test The Rest Timer Goes To The Top After A Warm-Up Or Another Exercise")
    func testRestAtTop() {
        let warmedUp = exercise("e1", sets: [set("w", isWarmup: true, doneAt: 0), set("s1")])
        #expect(ActiveWorkout.restAnchor(in: warmedUp, restedSet: warmedUp.sets[0], restStartedAt: start) == .top)

        let bench = exercise("e2", sets: [set("b1", doneAt: 0)])
        let squat = exercise("e1", sets: [set("s1")])
        #expect(ActiveWorkout.restAnchor(in: squat, restedSet: bench.sets[0], restStartedAt: start) == .top)
    }

    /// A set logged after the rest began, with no rest of its own, takes the timer away.
    @Test("Test The Rest Timer Is Left Out Once A Later Set Is Logged")
    func testRestHiddenAfterLaterSet() {
        let squat = exercise("e1", sets: [set("s1", doneAt: 0), set("s2", doneAt: 120)])

        let anchor = ActiveWorkout.restAnchor(
            in: squat,
            restedSet: ActiveWorkout.latestCompletedSet(in: [squat]),
            restStartedAt: start.addingTimeInterval(1)
        )

        #expect(anchor == nil)
    }

    // MARK: - Log button

    @Test("Test The Log Button Logs The Current Set, Then Moves On, Then Finishes")
    func testPrimaryAction() {
        let squat = exercise("e1", sets: [set("s1", doneAt: 0), set("s2")])
        let bench = exercise("e2", name: "Bench Press", sets: [set("b1")])

        #expect(ActiveWorkout.primaryAction(exercises: [squat, bench], currentExerciseId: "e1") == .logSet(exerciseId: "e1", setId: "s2"))

        let squatDone = exercise("e1", sets: [set("s1", doneAt: 0), set("s2", doneAt: 1)])
        #expect(ActiveWorkout.primaryAction(exercises: [squatDone, bench], currentExerciseId: "e1") == .next(exerciseId: "e2"))
        // Wraps round to an exercise skipped earlier.
        #expect(ActiveWorkout.primaryAction(exercises: [bench, squatDone], currentExerciseId: "e1") == .next(exerciseId: "e2"))

        let benchDone = exercise("e2", sets: [set("b1", doneAt: 2)])
        #expect(ActiveWorkout.primaryAction(exercises: [squatDone, benchDone], currentExerciseId: "e2") == .finish)
        #expect(ActiveWorkout.primaryAction(exercises: [], currentExerciseId: nil) == nil)
    }

    @Test("Test The Log Button Reads The Set As Typed")
    func testLogTitle() {
        let squat = exercise("e1", sets: [set("w", weightKg: 60, isWarmup: true), set("s1", weightKg: 115), set("s2", weightKg: 115)])

        #expect(ActiveWorkout.logTitle(for: squat.sets[2], in: squat, unit: .kilograms, distanceUnit: .meters) == "Log set 2 · 115 kg × 5")
        #expect(ActiveWorkout.logTitle(for: squat.sets[0], in: squat, unit: .kilograms, distanceUnit: .meters) == "Log warm-up · 60 kg × 5")

        let noReps = exercise("e1", sets: [set("s1", reps: nil)])
        #expect(ActiveWorkout.logTitle(for: noReps.sets[0], in: noReps, unit: .kilograms, distanceUnit: .meters) == "Log set 1")
    }

    /// A new timed set holds no duration, only a greyed placeholder, so the button shows no
    /// figures and one tap cannot log an invented minute. Assistance reads as a negative weight.
    @Test("Test The Log Button Shows No Figures Until A Time Is Entered")
    func testLogTitlePlaceholder() {
        var plank = exercise("e1", name: "Plank", sets: WorkoutSessionModel.defaultSets(trackingMode: .timeOnly, authorId: "author-1", targetCount: 1))
        plank.trackingMode = .timeOnly
        #expect(ActiveWorkout.logTitle(for: plank.sets[0], in: plank, unit: .kilograms, distanceUnit: .meters) == "Log set 1")
        plank.sets[0].durationSec = 42
        #expect(ActiveWorkout.logTitle(for: plank.sets[0], in: plank, unit: .kilograms, distanceUnit: .meters) == "Log set 1 · 0:42")

        let pullUp = exercise("e2", name: "Assisted Pull-Up", sets: [set("s1", reps: 8, weightKg: -30)])
        #expect(ActiveWorkout.logTitle(for: pullUp.sets[0], in: pullUp, unit: .kilograms, distanceUnit: .meters) == "Log set 1 · -30 kg × 8")
    }

    @Test("Test Up Next Shows The Plan And Last Time's Top Set")
    func testUpNextSummary() {
        let bench = exercise("e2", sets: [set("a"), set("b"), set("c")], targets: [SetTarget(setNumber: 1, minReps: 8, maxReps: 12)])
        let last = exercise("e0", sets: [set("a", weightKg: 80, doneAt: 0), set("b", weightKg: 82.5, doneAt: 1)])

        #expect(ActiveWorkout.upNextSummary(for: bench, last: last, unit: .kilograms, distanceUnit: .meters) == "3 sets · 8–12 reps · Last 82.5 kg × 5")
    }

    @Test("Test An Exercise Left Half Done Says How Far It Got")
    func testUpNextProgress() {
        let bench = exercise("e2", sets: [set("a", doneAt: 0), set("b"), set("c")])
        #expect(ActiveWorkout.upNextSummary(for: bench, last: nil, unit: .kilograms, distanceUnit: .meters) == "1 of 3 sets")
    }

    @Test("Test A Finished Exercise Shows Today's Top Set")
    func testCompletedSummary() {
        let bench = exercise("e1", sets: [
            set("w", weightKg: 40, isWarmup: true, doneAt: 0),
            set("a", weightKg: 80, doneAt: 1),
            set("b", reps: 6, weightKg: 85, doneAt: 2)
        ])

        #expect(ActiveWorkout.completedSummary(for: bench, unit: .kilograms, distanceUnit: .meters) == "2 sets · Top 85 kg × 6")
    }

    private func timed(_ id: String, seconds: Int?, meters: Double? = nil, doneAt offset: TimeInterval) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: nil, weightKg: nil, durationSec: seconds, distanceMeters: meters,
            rpe: nil, side: nil, isWarmup: false, completedAt: start.addingTimeInterval(offset), dateCreated: start
        )
    }

    private func exercise(_ id: String, mode: TrackingMode, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: id, authorId: "author-1", templateId: "template-\(id)", name: "Plank", trackingMode: mode, index: 1, sets: sets)
    }

    /// Every timed set weighs nothing and has no reps, so "heaviest" picked the first; the longest
    /// hold is the top one.
    @Test("Test A Timed Exercise's Top Set Is The Longest")
    func testTimedTopSet() {
        let plank = exercise("e1", mode: .timeOnly, sets: [
            timed("a", seconds: 30, doneAt: 0), timed("b", seconds: 45, doneAt: 1), timed("c", seconds: 40, doneAt: 2)
        ])

        #expect(ActiveWorkout.completedSummary(for: plank, unit: .kilograms, distanceUnit: .meters) == "3 sets · Top \(Format.duration(45))")
        #expect(ActiveWorkout.upNextSummary(for: exercise("e2", mode: .timeOnly, sets: []), last: plank, unit: .kilograms, distanceUnit: .meters)
            .hasSuffix("Last \(Format.duration(45))"))
    }

    @Test("Test A Distance Exercise's Top Set Is The Farthest")
    func testDistanceTopSet() {
        let row = exercise("e1", mode: .distanceTime, sets: [
            timed("a", seconds: 90, meters: 400, doneAt: 0), timed("b", seconds: 200, meters: 800, doneAt: 1), timed("c", seconds: 95, meters: 500, doneAt: 2)
        ])
        let figures = "\(Format.distance(meters: 800, exerciseUnit: .meters)) · \(Format.duration(200))"

        #expect(ActiveWorkout.completedSummary(for: row, unit: .kilograms, distanceUnit: .meters) == "3 sets · Top \(figures)")
        #expect(ActiveWorkout.upNextSummary(for: exercise("e2", mode: .distanceTime, sets: []), last: row, unit: .kilograms, distanceUnit: .meters)
            .hasSuffix("Last \(figures)"))
    }

    // MARK: - Plates

    @Test("Test A Load Rounds To The Nearest Total The Plates Make")
    func testNearestLoadable() {
        let plates = [1.25, 2.5, 5, 10, 20]
        #expect(PlateCalculator.nearestLoadable(total: 100, bar: 20, plates: plates) == 100)
        #expect(PlateCalculator.nearestLoadable(total: 101, bar: 20, plates: plates) == 100)
        #expect(PlateCalculator.nearestLoadable(total: 102, bar: 20, plates: plates) == 102.5)
        // Halfway goes lighter.
        #expect(PlateCalculator.nearestLoadable(total: 101.25, bar: 20, plates: plates) == 100)
        // Below the bar the bar is the nearest.
        #expect(PlateCalculator.nearestLoadable(total: 15, bar: 20, plates: plates) == 20)
    }

    /// Smart progression's suggestion on a barbell lands on a total the gym can load, not on the
    /// nearest half kilogram.
    @Test("Test Prescribed Barbell Loads Round To The Plates")
    func testRoundingRuleUsesPlates() {
        let rule = WeightRoundingRule(
            equipment: nil,
            preferredUnit: .kilograms,
            plateLoading: .init(bar: 20, plates: [2.5, 5, 10, 20], unit: .kilograms)
        )

        #expect(rule.round(101.5) == 100)
        #expect(rule.round(103) == 105)
        #expect(rule.minimumIncrementKg == 5)

        let unplated = WeightRoundingRule(equipment: nil, preferredUnit: .kilograms)
        #expect(unplated.round(101.5) == 101.5)
    }

    @Test("Test Pound Plates Round In Pounds")
    func testRoundingRuleInPounds() {
        let rule = WeightRoundingRule(
            equipment: nil,
            preferredUnit: .pounds,
            plateLoading: .init(bar: 45, plates: [2.5, 5, 10, 25, 45], unit: .pounds)
        )
        // 228 lb is not loadable on a 45 lb bar; 225 and 230 are, and 230 is nearer.
        let rounded = UnitConversion.convertWeight(rule.round(UnitConversion.convertWeightToKg(228, from: ExerciseWeightUnit.pounds)), to: ExerciseWeightUnit.pounds)
        #expect(abs(rounded - 230) < 0.01)
        #expect(abs(rule.minimumIncrementKg - UnitConversion.convertWeightToKg(5, from: ExerciseWeightUnit.pounds)) < 0.001)
    }

    private func gym(plates: [Double]) -> GymProfileModel {
        GymProfileModel(
            authorId: "u",
            freeWeights: [FreeWeights(
                id: "weight_plates", name: "Plates", needsColour: true,
                range: plates.map { FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: .kilograms, isActive: true) },
                isActive: true
            )],
            loadableBars: [LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
                LoadableBarsBaseWeight(id: "b20", baseWeight: 20, unit: .kilograms, isActive: true)
            ], isActive: true)],
            cableMachines: [], plateLoadedMachines: [], pinLoadedMachines: []
        )
    }

    /// A gym whose lightest plate is 5 kg is probably missing its small plates; rounding to it would
    /// make every progression step 10 kg, so progression keeps its half-kilogram rounding there.
    @Test("Test Progression Only Rounds To Plates With Small Plates In The Gym")
    func testRoundingRuleNeedsSmallPlates() {
        let bar = [EquipmentRef(kind: .loadableBar, id: "barbell")]
        let small = WeightRoundingRule(exercise: nil, gymProfile: gym(plates: [1.25, 2.5, 5, 10, 20]), preferredWeightUnit: .kilograms, resistanceEquipment: bar)
        let coarse = WeightRoundingRule(exercise: nil, gymProfile: gym(plates: [5, 10, 20]), preferredWeightUnit: .kilograms, resistanceEquipment: bar)

        #expect(small.plateLoading != nil)
        #expect(coarse.plateLoading == nil)
        #expect(coarse.minimumIncrementKg == 2.5)
    }
}

/// The log button and the inline rest timer on the live screen.
@MainActor
struct ActiveWorkoutPresenterTests {

    private func makePresenter(sets: [WorkoutSetModel], autoNext: Bool = true) throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.exerciseAutoNext = autoNext
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Legs",
            dateCreated: Date(),
            exercises: [
                WorkoutExerciseModel(id: "e1", authorId: "author-1", templateId: "t1", name: "Squat", trackingMode: .weightReps, index: 1, sets: sets),
                WorkoutExerciseModel(id: "e2", authorId: "author-1", templateId: "t2", name: "Lunge", trackingMode: .weightReps, index: 2, sets: [
                    WorkoutSetModel(id: "l1", authorId: "author-1", index: 1, reps: 10, weightKg: 20, isWarmup: false, completedAt: nil, dateCreated: Date())
                ])
            ]
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    private func openSet(_ id: String, reps: Int? = 5) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: reps, weightKg: 100, isWarmup: false, completedAt: nil, dateCreated: Date())
    }

    @Test("Test The Log Button Logs The Set, Rests And Moves The Title On")
    func testLogButton() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1"), openSet("s2")])
        #expect(presenter.primaryActionTitle == "Log set 1 · 100 kg × 5")

        presenter.onPrimaryActionPressed()

        #expect(presenter.workoutSession.exercises[0].sets[0].completedAt != nil)
        #expect(interactor.startedRests == [90])
        #expect(presenter.primaryActionTitle == "Log set 2 · 100 kg × 5")
        #expect(presenter.restTimer(for: presenter.workoutSession.exercises[0])?.anchor == .below(setId: "s1"))
    }

    @Test("Test The Log Button Refuses A Set With No Reps")
    func testLogButtonValidates() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1", reps: nil)])

        presenter.onPrimaryActionPressed()

        #expect(presenter.workoutSession.exercises[0].sets[0].completedAt == nil)
        #expect(interactor.startedRests.isEmpty)
    }

    /// With auto-next off the card stays on the finished exercise and the button offers the next.
    @Test("Test After The Last Set The Button Offers The Next Exercise")
    func testNextExercise() throws {
        let (presenter, _) = try makePresenter(sets: [openSet("s1")], autoNext: false)

        presenter.onPrimaryActionPressed()
        #expect(presenter.primaryActionTitle == "Next: Lunge")

        presenter.onPrimaryActionPressed()
        #expect(presenter.currentExercise?.id == "e2")
        #expect(presenter.upNextExercises.isEmpty)
        #expect(presenter.completedExercises.map(\.id) == ["e1"])
    }

    /// Unticking the set a rest follows calls the rest off, and the timer goes with it.
    @Test("Test Undoing The Set Cancels Its Rest")
    func testUndoCancelsRest() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1"), openSet("s2")])
        presenter.onPrimaryActionPressed()
        #expect(interactor.restEndTime != nil)

        // What the row's Done does on a logged set: it writes through the binding.
        presenter.workoutSession.exercises[0].sets[0].completedAt = nil

        #expect(interactor.didCancelRest)
        #expect(presenter.restTimer(for: presenter.workoutSession.exercises[0]) == nil)
    }

    // MARK: - Reordering

    /// One open set per exercise; those in `done` are already logged.
    private func makeWorkout(_ ids: [String], superset: Set<String> = [], done: Set<String> = []) throws -> WorkoutTrackerPresenter {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Legs", dateCreated: Date(),
            exercises: ids.enumerated().map { index, id in
                var set = openSet("\(id)-1")
                if done.contains(id) { set.completedAt = Date() }
                return WorkoutExerciseModel(
                    id: id, authorId: "author-1", templateId: "t-\(id)", name: id, trackingMode: .weightReps,
                    index: index + 1, sets: [set], supersetGroupId: superset.contains(id) ? "g" : nil
                )
            }
        )
        return try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble())
    }

    /// The machine is taken: the exercise on the card goes to the end and the card moves on.
    @Test("Test Doing The Card's Exercise Later Moves It To The End")
    func testDoLaterFromCard() throws {
        let presenter = try makeWorkout(["squat", "press", "row"])
        #expect(presenter.currentExercise?.id == "squat")

        presenter.onDoLaterPressed("squat")

        #expect(presenter.workoutSession.exercises.map(\.id) == ["press", "row", "squat"])
        #expect(presenter.currentExercise?.id == "press")
        #expect(presenter.workoutSession.exercises.map(\.index) == [1, 2, 3])
    }

    @Test("Test A Superset Is Put Off And Brought Forward Together")
    func testSupersetMovesTogether() throws {
        let presenter = try makeWorkout(["squat", "curl", "dip", "row"], superset: ["curl", "dip"])

        presenter.onDoLaterPressed("dip")
        #expect(presenter.workoutSession.exercises.map(\.id) == ["squat", "row", "curl", "dip"])
        #expect(presenter.currentExercise?.id == "squat")

        presenter.onDoNextPressed("curl")
        #expect(presenter.workoutSession.exercises.map(\.id) == ["squat", "curl", "dip", "row"])
        #expect(presenter.currentExercise?.id == "squat")
    }

    @Test("Test The Last Exercise Left Cannot Be Put Off")
    func testCannotDoLaterAlone() throws {
        let presenter = try makeWorkout(["squat", "press"])
        let squat = try #require(presenter.currentExercise)
        #expect(presenter.canDoLater(squat))

        presenter.workoutSession.exercises[1].sets[0].completedAt = Date()
        #expect(!presenter.canDoLater(presenter.workoutSession.exercises[0]))
    }

    /// A rest set by hand on a row is kept by the screen, so the log button rests as long.
    @Test("Test A Rest Set By Hand Holds From The Log Button And The Row")
    func testCustomRest() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1"), openSet("s2"), openSet("s3")])
        presenter.customRestSeconds["s1"] = 200

        presenter.onPrimaryActionPressed()
        // The row's Done, with its own rest.
        presenter.logSet("s2", in: "e1", customRestSeconds: 45, source: "row")

        #expect(interactor.startedRests == [200, 45])
        // One event for every set logged, whichever way, told apart by its source.
        #expect(interactor.trackedEventNames.filter { $0 == "SetTrackerRow_SetCompleted" }.count == 2)
        #expect(interactor.lastParameters["SetTrackerRow_SetCompleted"]?["source"] as? String == "row")
    }

    /// The reason shows as the exercise starts, until it is acknowledged or a working set is logged.
    @Test("Test The Progression Note Shows Until Acknowledged Or Started")
    func testProgressionNote() throws {
        let (presenter, _) = try makePresenter(sets: [openSet("s1"), openSet("s2")])
        presenter.previousExercises["t1"] = WorkoutExerciseModel(
            id: "last", authorId: "author-1", templateId: "t1", name: "Squat", trackingMode: .weightReps, index: 1,
            sets: [WorkoutSetModel(id: "l", authorId: "author-1", index: 1, reps: 5, weightKg: 97.5, isWarmup: false, completedAt: Date(), dateCreated: Date())]
        )
        presenter.progressionSuggestions["t1"] = ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 100, reps: 5)])

        #expect(presenter.progressionNote == "+2.5 kg today. You hit 5 reps on every working set last time.")

        presenter.onProgressionNoteAcknowledged()
        #expect(presenter.progressionNote == nil)

        // A second exercise of the same kind starts with its note showing; logging a set ends it.
        presenter.acknowledgedProgressionNotes = []
        presenter.onPrimaryActionPressed()
        #expect(presenter.progressionNote == nil)
    }

    @Test("Test A Session Started Without An Exercise's Image Takes It From The Library")
    func testMissingImagesComeFromTheLibrary() throws {
        let (_, interactor) = try makePresenter(sets: [openSet("s1")])
        var squat = ExerciseModel.mock
        squat.id = "t1"
        squat.imageURL = "BarbellSquat"
        interactor.allExercises = [squat]

        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble())

        #expect(presenter.workoutSession.exercises.map(\.imageName) == ["BarbellSquat", nil])
    }

    @Test("Test Skipping The Rest Removes The Timer")
    func testSkipRemovesTimer() throws {
        let (presenter, _) = try makePresenter(sets: [openSet("s1"), openSet("s2")])
        presenter.onPrimaryActionPressed()

        presenter.onSkipRestPressed()

        #expect(presenter.restTimer(for: presenter.workoutSession.exercises[0]) == nil)
    }

    /// Up Next leaves out the card and anything finished, so a drag in it must land in the right
    /// place among the exercises it does not show.
    @Test("Test Reordering Up Next Maps Round The Rows It Does Not Show")
    func testMoveUpNext() throws {
        let presenter = try makeWorkout(["a", "b", "c", "d"], done: ["b"])
        #expect(presenter.upNextExercises.map(\.id) == ["c", "d"])

        presenter.moveUpNext(from: IndexSet(integer: 1), to: 0)

        #expect(presenter.workoutSession.exercises.map(\.id) == ["a", "b", "d", "c"])
        #expect(presenter.currentExercise?.id == "a")
    }

    /// Finishing an exercise opens the next with sets left, as the log button's Next would, not
    /// one done earlier that happens to come next in the list. It waits for the rest first.
    @Test("Test Finishing An Exercise Skips Over One Already Done")
    func testAutoAdvanceSkipsFinished() throws {
        let presenter = try makeWorkout(["a", "b", "c"], done: ["b"])

        presenter.onPrimaryActionPressed()
        #expect(presenter.currentExercise?.id == "a")
        #expect(presenter.primaryActionTitle == "Next: c")

        presenter.onSkipRestPressed()

        #expect(presenter.currentExercise?.id == "c")
        #expect(presenter.primaryActionTitle == "Log set 1 · 100 kg × 5")
    }

    /// An older session stored no image for an exercise the library has since given one; the
    /// tracker fills it from the library and leaves the rest as it was.
    @Test("Test Missing Images Are Filled From The Library")
    func testFillingMissingImages() throws {
        let presenter = try makeWorkout(["squat", "press"])
        var session = presenter.workoutSession
        session.exercises[0].imageName = nil
        session.exercises[1].imageName = "press-stored"
        var squat = ExerciseModel(
            id: "t-squat", authorId: "author-1", name: "Squat", trackableMetrics: [.weight, .reps], type: .compoundLower,
            laterality: .bilateral, muscleGroups: [.quads: .primary], isBodyweight: false, rangeOfMotion: 4, stability: 5,
            bodyWeightContribution: 0, alternateNames: []
        )
        squat.imageURL = "squat-library"

        let filled = WorkoutTrackerPresenter.fillingMissingImages(session, from: [squat])

        #expect(filled.exercises.map(\.imageName) == ["squat-library", "press-stored"])
        #expect(WorkoutTrackerPresenter.fillingMissingImages(filled, from: [squat]) == filled)
    }
}

// MARK: - Bodyweight contribution (WP-O)

extension ActiveWorkoutStateTests {

    @Test("Test The Log Button Reads BW With The Bodyweight Contribution Shown")
    func testBodyweightLogTitle() {
        let dips = exercise("e1", name: "Dip", sets: [set("s1", reps: 8, weightKg: 20), set("s2", reps: 8, weightKg: nil), set("s3", reps: 8, weightKg: -20)])
        let kg20 = Format.weight(kg: 20, unit: .kilograms)

        #expect(ActiveWorkout.logTitle(for: dips.sets[0], in: dips, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "Log set 1 · BW + \(kg20) × 8")
        #expect(ActiveWorkout.logTitle(for: dips.sets[1], in: dips, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "Log set 2 · BW × 8")
        #expect(ActiveWorkout.logTitle(for: dips.sets[2], in: dips, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "Log set 3 · BW − \(kg20) × 8")
        // No reps yet: no figures, as without bodyweight.
        let noReps = exercise("e1", sets: [set("s1", reps: nil, weightKg: 20)])
        #expect(ActiveWorkout.logTitle(for: noReps.sets[0], in: noReps, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "Log set 1")
    }

    @Test("Test With The Bodyweight Contribution Hidden The Figures Are Unchanged")
    func testBodyweightOffUnchanged() {
        let dips = exercise("e1", name: "Dip", sets: [set("s1", reps: 8, weightKg: 20), set("s2", reps: 8, weightKg: nil)])

        #expect(ActiveWorkout.logTitle(for: dips.sets[0], in: dips, unit: .kilograms, distanceUnit: .meters, showsBodyweight: false) == "Log set 1 · 20 kg × 8")
        #expect(ActiveWorkout.logTitle(for: dips.sets[1], in: dips, unit: .kilograms, distanceUnit: .meters) == "Log set 2 · 8 reps")
        // Time and distance have no load to add bodyweight to.
        let plank = WorkoutSetModel(id: "p", authorId: "author-1", index: 1, durationSec: 90, isWarmup: false, dateCreated: start)
        #expect(ActiveWorkout.figures(of: plank, trackingMode: .timeOnly, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == Format.duration(90))
    }

    @Test("Test The Summaries Read BW With The Bodyweight Contribution Shown")
    func testBodyweightSummaries() {
        let pullUps = exercise("e1", name: "Pull-Up", sets: [set("a", reps: 8, weightKg: 10, doneAt: 0), set("b", reps: 6, weightKg: 20, doneAt: 1)])
        let kg20 = Format.weight(kg: 20, unit: .kilograms)

        #expect(ActiveWorkout.completedSummary(for: pullUps, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "2 sets · Top BW + \(kg20) × 6")
        let today = exercise("e2", name: "Pull-Up", sets: [set("c")])
        #expect(ActiveWorkout.upNextSummary(for: today, last: pullUps, unit: .kilograms, distanceUnit: .meters, showsBodyweight: true) == "1 set · Last BW + \(kg20) × 6")
    }
}

// MARK: - Bodyweight contribution on the tracker (WP-O)

extension ActiveWorkoutPresenterTests {

    private func libraryExercise(_ id: String, percent: Int) -> ExerciseModel {
        ExerciseModel(
            id: id, authorId: "author-1", name: id, trackableMetrics: [.weight, .reps], type: .compoundLower,
            laterality: .bilateral, muscleGroups: [.quads: .primary], isBodyweight: false, rangeOfMotion: 4, stability: 5,
            bodyWeightContribution: percent, alternateNames: []
        )
    }

    @Test("Test The Tracker Reads BW And Counts Bodyweight In Volume With The Setting On")
    func testBodyweightOnTracker() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1"), openSet("s2")])
        interactor.allExercises = [libraryExercise("t1", percent: 50)]
        interactor.currentWeightKilograms = 80
        let off = presenter.computeTotalVolumeKg()
        #expect(presenter.primaryActionTitle == "Log set 1 · 100 kg × 5")
        #expect(presenter.bodyweightContribution(for: presenter.workoutSession.exercises[0]) == nil)

        interactor.workoutSettings.showBodyweightContribution = true

        let squat = presenter.workoutSession.exercises[0]
        #expect(presenter.bodyweightContribution(for: squat) == BodyweightContribution(percent: 50, bodyweightKg: 80, unit: .kilograms))
        #expect(presenter.primaryActionTitle == "Log set 1 · BW + \(Format.weight(kg: 100, unit: .kilograms)) × 5")
        // Two sets of 5 gain 40 kg of bodyweight a rep; the lunge lifts none.
        #expect(presenter.computeTotalVolumeKg() == off + 2 * 5 * 40)
        #expect(presenter.bodyweightContribution(for: presenter.workoutSession.exercises[1]) == nil)
    }

    @Test("Test With No Bodyweight Known The Labels Stay And Volume Does Not Grow")
    func testBodyweightUnknown() throws {
        let (presenter, interactor) = try makePresenter(sets: [openSet("s1")])
        interactor.allExercises = [libraryExercise("t1", percent: 100)]
        let off = presenter.computeTotalVolumeKg()
        interactor.workoutSettings.showBodyweightContribution = true

        #expect(presenter.bodyweightContribution(for: presenter.workoutSession.exercises[0])?.contributionKg == nil)
        #expect(presenter.primaryActionTitle.contains("BW + "))
        #expect(presenter.computeTotalVolumeKg() == off)
    }
}
