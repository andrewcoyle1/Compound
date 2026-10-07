//
//  WorkoutTemplateDetailPresenterTests.swift
//  CompoundUnitTests
//
//  The template detail reads a mesocycle's day for the week it was opened on: "Week 3 · 3 sets ·
//  8–10 · RIR 1", the plan's own columns, and Start on that week's targets.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct WorkoutTemplateDetailPresenterTests {

    private func targets(_ count: Int, reps: ClosedRange<Int>? = 8...10, rir: Int? = nil) -> [SetTarget] {
        (1...count).map { SetTarget(setNumber: $0, minReps: reps?.lowerBound, maxReps: reps?.upperBound, rirTarget: rir) }
    }

    /// Two sets at RIR 2 in week 1, three at RIR 1 from week 2, four at RIR 0 from week 9.
    private func varied() -> WorkoutTemplateExercise {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setTargets: targets(2, rir: 2), setRestTimers: false)
        exercise.setTargetsByMicrocycle = [
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: targets(4, rir: 0)),
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: targets(3, rir: 1))
        ]
        return exercise
    }

    // MARK: - Summaries

    @Test("Test A Week's Summary Reads Its Own Targets")
    func testAWeeksSummaryReadsItsOwnTargets() {
        #expect(varied().weekSummary(microcycle: 3) == "Week 3 · 3 sets · 8–10 · RIR 1")
        #expect(varied().weekSummary(microcycle: 1) == "Week 1 · 2 sets · 8–10 · RIR 2")
        #expect(varied().weekSummary(microcycle: 12) == "Week 12 · 4 sets · 8–10 · RIR 0")
    }

    @Test("Test Without A Week The Summary Is The Base Targets")
    func testWithoutAWeekTheSummaryIsTheBaseTargets() {
        #expect(varied().weekSummary(microcycle: nil) == "2 sets · 8–10 · RIR 2")
    }

    @Test("Test A Summary Leaves Out What The Plan Does Not Set")
    func testASummaryLeavesOutWhatThePlanDoesNotSet() {
        #expect(WorkoutTemplateExercise.targetSummary(targets(1, reps: nil)) == "1 set")
        #expect(WorkoutTemplateExercise.targetSummary(targets(3, reps: 20...20)) == "3 sets · 20")
        let mixed = [SetTarget(setNumber: 1, minReps: 6, maxReps: 8, rirTarget: 2), SetTarget(setNumber: 2, minReps: 10, maxReps: 12, rirTarget: 0)]
        #expect(WorkoutTemplateExercise.targetSummary(mixed) == "2 sets · 6–12 · RIR 0–2")
    }

    @Test("Test The Variation Summary Lists Each Stretch Of Weeks")
    func testTheVariationSummaryListsEachStretchOfWeeks() {
        #expect(varied().variationSummary == "Week 1: 2 sets, 8–10, RIR 2 · Weeks 2–8: 3 sets, 8–10, RIR 1 · From week 9: 4 sets, 8–10, RIR 0")

        var twoStretches = WorkoutTemplateExercise(exercise: .mock, setTargets: targets(2), setRestTimers: false)
        twoStretches.setTargetsByMicrocycle = [MicrocycleSetTargets(fromMicrocycle: 2, setTargets: targets(3))]
        #expect(twoStretches.variationSummary == "Week 1: 2 sets, 8–10 · From week 2: 3 sets, 8–10")
    }

    @Test("Test Targets That Never Change Have No Variation Summary")
    func testTargetsThatNeverChangeHaveNoVariationSummary() {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setTargets: targets(2), setRestTimers: false)
        #expect(exercise.variationSummary == nil)
        // An override from week 1 replaces the base; it is not a change during the block.
        exercise.setTargetsByMicrocycle = [MicrocycleSetTargets(fromMicrocycle: 1, setTargets: targets(3))]
        #expect(exercise.variationSummary == nil)
        #expect(exercise.weekSummary(microcycle: 1) == "Week 1 · 3 sets · 8–10")
    }

    // MARK: - Plan fields

    @Test("Test Supersets Are Lettered In The Order They First Appear")
    func testSupersetsAreLetteredInTheOrderTheyFirstAppear() {
        let groups: [String?] = ["late", nil, "early", "late", "alone", "early"]
        let exercises = groups.map { group in
            var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
            exercise.supersetGroupId = group
            return exercise
        }

        #expect(WorkoutTemplateExercise.supersetLetters(in: exercises) == ["late": "A", "early": "B"])
    }

    @Test("Test Alternatives Are Named From The Library And Unknown Ids Skipped")
    func testAlternativesAreNamedFromTheLibraryAndUnknownIdsSkipped() {
        let library = Array(ExerciseModel.mocks.prefix(3))
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.substituteExerciseIds = [library[2].id, "gone", library[1].id]

        #expect(exercise.alternativeNames(in: library) == [library[2].name, library[1].name])
    }

    @Test("Test Only A Web Link Opens")
    func testOnlyAWebLinkOpens() {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        #expect(exercise.planLink == nil)
        exercise.linkURL = " https://example.com/bench "
        #expect(exercise.planLink?.absoluteString == "https://example.com/bench")
        exercise.linkURL = "javascript:alert(1)"
        #expect(exercise.planLink == nil)
    }

    // MARK: - The screen

    private typealias Doubles = TrainingTemplateDetailPresenterTests

    private func makePresenter(library: [ExerciseModel] = []) -> (WorkoutTemplateDetailPresenter, Doubles.Interactor) {
        let interactor = Doubles.Interactor()
        interactor.allExercises = library
        return (WorkoutTemplateDetailPresenter(interactor: interactor, router: Doubles.Router()), interactor)
    }

    private func delegate(_ exercises: [WorkoutTemplateExercise], week: Int?) -> WorkoutTemplateDetailDelegate {
        WorkoutTemplateDetailDelegate(
            workoutTemplate: WorkoutTemplateModel(id: "push", authorId: "me", name: "Push", exercises: exercises),
            mesocycleId: week == nil ? nil : "program-1",
            onStartWorkoutPressed: nil,
            microcycleIndex: week
        )
    }

    @Test("Test The Screen Reads The Week It Was Opened On")
    func testTheScreenReadsTheWeekItWasOpenedOn() {
        let (presenter, _) = makePresenter()
        let exercise = varied()

        #expect(presenter.weekSummary(for: exercise, delegate: delegate([exercise], week: 3)) == "Week 3 · 3 sets · 8–10 · RIR 1")
        #expect(presenter.weekSummary(for: exercise, delegate: delegate([exercise], week: nil)) == "2 sets · 8–10 · RIR 2")
        #expect(presenter.exerciseForWeek(exercise, delegate: delegate([exercise], week: 3)).setTargets.count == 3)
        #expect(presenter.exerciseForWeek(exercise, delegate: delegate([exercise], week: nil)).setTargets.count == 2)
    }

    @Test("Test The Screen Names Alternatives And Letters Supersets")
    func testTheScreenNamesAlternativesAndLettersSupersets() {
        let library = Array(ExerciseModel.mocks.prefix(2))
        let (presenter, _) = makePresenter(library: library)
        var first = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        first.substituteExerciseIds = [library[1].id, "gone"]
        first.supersetGroupId = "g"
        var second = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        second.supersetGroupId = "g"

        #expect(presenter.alternativeNames(for: first) == [library[1].name])
        #expect(presenter.supersetLabels(in: [first, second]) == ["g": "Superset A"])
    }

    @Test("Test Start Runs The Week The Screen Was Opened On")
    func testStartRunsTheWeekTheScreenWasOpenedOn() async {
        let (presenter, interactor) = makePresenter()

        presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: WorkoutTemplateModel(id: "push", authorId: "me", name: "Push", exercises: [varied()]),
            mesocycleId: "program-1",
            microcycleIndex: 3
        )

        #expect(await TestManagers.eventually { interactor.startedMicrocycles == [3] })
        #expect(interactor.startedIn == ["program-1"])
    }

    @Test("Test A Template On Its Own Starts On Its Base Targets")
    func testATemplateOnItsOwnStartsOnItsBaseTargets() async {
        let (presenter, interactor) = makePresenter()

        presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: WorkoutTemplateModel(id: "push", authorId: "me", name: "Push", exercises: [varied()]),
            mesocycleId: nil
        )

        #expect(await TestManagers.eventually { interactor.startedMicrocycles == [nil] })
    }
}
