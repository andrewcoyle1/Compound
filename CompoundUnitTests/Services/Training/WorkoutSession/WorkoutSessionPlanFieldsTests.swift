//
//  WorkoutSessionPlanFieldsTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The plan's per-exercise columns on a session exercise.
@MainActor
struct WorkoutSessionPlanFieldsTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Session exercise coding

    private func sessionExercise() -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "library-1",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            notes: "Felt strong",
            sets: []
        )
    }

    @Test("Test A Session Exercise Saved Before The Plan Fields Decodes With Them Empty")
    func testAnOldSessionExerciseDecodes() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sessionExercise())) as? [String: Any] ?? [:]
        #expect(json["plan_notes"] == nil)
        #expect(json["substitute_exercise_ids"] == nil)
        json.removeValue(forKey: "set_targets")
        json.removeValue(forKey: "equipment_variations")

        let decoded = try JSONDecoder().decode(WorkoutExerciseModel.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded == sessionExercise())
        #expect(decoded.notes == "Felt strong")
        #expect(decoded.planNotes == nil)
        #expect(decoded.restSeconds == nil)
        #expect(decoded.linkURL == nil)
        #expect(decoded.substituteExerciseIds.isEmpty)
    }

    @Test("Test The Plan Fields Round-Trip Beside The User's Own Notes")
    func testThePlanFieldsRoundTrip() throws {
        var original = sessionExercise()
        original.planNotes = "Pause at the bottom"
        original.restSeconds = 120
        original.linkURL = "https://example.com/video"
        original.substituteExerciseIds = ["sub-1"]

        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        #expect(try JSONDecoder().decode(WorkoutExerciseModel.self, from: data) == original)
        #expect(json["plan_notes"] as? String == "Pause at the bottom")
        #expect(json["rest_seconds"] as? Int == 120)
        #expect(json["link_url"] as? String == "https://example.com/video")
        #expect(json["substitute_exercise_ids"] as? [String] == ["sub-1"])
        #expect(json["notes"] as? String == "Felt strong")
    }

    // MARK: - Starting a session from a template

    private let library = ExerciseModel(
        id: "library-1",
        authorId: "author-1",
        name: "Bench Press",
        trackableMetrics: [.weight, .reps],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: [.chest: .primary],
        isBodyweight: false,
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: []
    )

    private func targets(_ count: Int, reps: Int = 8) -> [SetTarget] {
        (1...count).map { SetTarget(id: "target-\(count)-\($0)", setNumber: $0, minReps: reps, maxReps: reps + 2) }
    }

    private func template(_ exercises: [WorkoutTemplateExercise]) -> WorkoutTemplateModel {
        WorkoutTemplateModel(id: "template-1", authorId: "author-1", name: "Push Day", exercises: exercises)
    }

    private func begin(_ template: WorkoutTemplateModel, microcycle: Int? = nil, previous: WorkoutSessionModel? = nil) -> WorkoutSessionModel {
        WorkoutSessionModel(
            authorId: "author-1",
            template: template,
            microcycleIndex: microcycle,
            previousWorkoutSession: previous,
            dateCreated: start
        )
    }

    /// One logged exercise of `library`, at `index`, with one set at `weight` for `reps`.
    private func logged(id: String, index: Int, weight: Double, reps: Int) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: library.id,
            name: library.name,
            trackingMode: .weightReps,
            index: index,
            sets: [WorkoutSetModel(
                id: "\(id)-set", authorId: "author-1", index: 1, reps: reps, weightKg: weight,
                isWarmup: false, completedAt: start, dateCreated: start
            )]
        )
    }

    @Test("Test The Microcycle Picks Its Override, And None Gives The Base")
    func testTheMicrocyclePicksItsOverride() {
        let entry = WorkoutTemplateExercise(
            exercise: library,
            setTargets: targets(2),
            setRestTimers: false,
            warmupSetCount: 0,
            setTargetsByMicrocycle: [MicrocycleSetTargets(fromMicrocycle: 2, setTargets: targets(4, reps: 6))]
        )

        let weekOne = begin(template([entry]))
        let weekThree = begin(template([entry]), microcycle: 3)

        #expect(weekOne.exercises[0].setTargets == targets(2))
        #expect(weekOne.exercises[0].sets.count == 2)
        #expect(weekThree.exercises[0].setTargets == targets(4, reps: 6))
        #expect(weekThree.exercises[0].sets.count == 4)
    }

    /// Through the interactor every start path calls: a mesocycle's day started in week 3 plans
    /// week 3's sets, and a template on its own its base.
    @Test("Test The Interactor Plans The Week's Targets")
    func testTheInteractorPlansTheWeeksTargets() async throws {
        let preview = DevPreview()
        let interactor = CoreInteractor(container: preview.container())
        #expect(await TestManagers.eventually { interactor.userId != nil })
        let entry = WorkoutTemplateExercise(
            exercise: library,
            setTargets: targets(2),
            setRestTimers: false,
            warmupSetCount: 0,
            setTargetsByMicrocycle: [MicrocycleSetTargets(fromMicrocycle: 3, setTargets: targets(4, reps: 6))]
        )

        let weekThree = try await interactor.plannedSession(for: template([entry]), in: "program-1", microcycleIndex: 3)
        let onItsOwn = try await interactor.plannedSession(for: template([entry]), in: nil, microcycleIndex: nil)

        #expect(weekThree.exercises[0].setTargets == targets(4, reps: 6))
        #expect(weekThree.exercises[0].workingSets.count == 4)
        #expect(onItsOwn.exercises[0].setTargets == targets(2))
        #expect(onItsOwn.exercises[0].workingSets.count == 2)
    }

    @Test("Test The Plan's Columns Are Copied Onto The Session Exercise")
    func testThePlansColumnsAreCopied() {
        let entry = WorkoutTemplateExercise(
            exercise: library,
            setTargets: targets(3),
            setRestTimers: false,
            notes: "Pause at the bottom",
            warmupSetCount: 4,
            restSeconds: 150,
            substituteExerciseIds: ["sub-1", "sub-2"],
            supersetGroupId: "group-a",
            linkURL: "https://example.com/video"
        )

        let exercise = begin(template([entry])).exercises[0]

        #expect(exercise.planNotes == "Pause at the bottom")
        #expect(exercise.notes == nil)
        #expect(exercise.restSeconds == 150)
        #expect(exercise.substituteExerciseIds == ["sub-1", "sub-2"])
        #expect(exercise.supersetGroupId == "group-a")
        #expect(exercise.linkURL == "https://example.com/video")
        #expect(exercise.sets.filter(\.isWarmup).count == 4)
        #expect(exercise.sets.filter { !$0.isWarmup }.count == 3)
    }

    /// A heavy set then a back-off of the same lift: each entry carries forward its own numbers,
    /// not the first one's.
    @Test("Test The Same Exercise Twice Matches Each Entry To Its Own Previous Exercise")
    func testTheSameExerciseTwiceMatchesByOccurrence() {
        let heavy = WorkoutTemplateExercise(exercise: library, setTargets: targets(1, reps: 6), setRestTimers: false)
        let backOff = WorkoutTemplateExercise(exercise: library, setTargets: targets(1, reps: 20), setRestTimers: false)
        let previous = WorkoutSessionModel(
            id: "previous", authorId: "author-1", name: "Push Day", dateCreated: start,
            // Listed out of index order: matching goes by index, not by position in the list.
            exercises: [logged(id: "back-off", index: 2, weight: 40, reps: 20), logged(id: "heavy", index: 1, weight: 100, reps: 6)]
        )

        let session = begin(template([heavy, backOff]), previous: previous)
        let working = session.exercises.map { $0.sets.filter { !$0.isWarmup } }

        #expect(working[0].map(\.weightKg) == [100])
        #expect(working[0].map(\.reps) == [6])
        #expect(working[1].map(\.weightKg) == [40])
        #expect(working[1].map(\.reps) == [20])
    }

    /// A second entry the previous session did not have starts blank rather than copying the first.
    @Test("Test A New Second Occurrence Has Nothing To Carry Forward")
    func testANewSecondOccurrenceHasNothingToCarryForward() {
        let entry = WorkoutTemplateExercise(exercise: library, setTargets: targets(1), setRestTimers: false)
        let previous = WorkoutSessionModel(
            id: "previous", authorId: "author-1", name: "Push Day", dateCreated: start,
            exercises: [logged(id: "heavy", index: 1, weight: 100, reps: 6)]
        )

        let session = begin(template([entry, entry]), previous: previous)

        #expect(session.exercises[0].sets.last?.weightKg == 100)
        #expect(session.exercises[1].sets.last?.weightKg == nil)
    }

    @Test("Test Occurrence And Its Lookup Count Appearances Of One Exercise In Index Order")
    func testOccurrenceAndItsLookup() {
        let other = WorkoutExerciseModel(
            id: "other", authorId: "author-1", templateId: "library-2", name: "Row",
            trackingMode: .weightReps, index: 2, sets: []
        )
        let first = logged(id: "first", index: 1, weight: 100, reps: 6)
        let second = logged(id: "second", index: 3, weight: 40, reps: 20)
        let session = WorkoutSessionModel(
            id: "session", authorId: "author-1", name: "Push Day", dateCreated: start,
            exercises: [second, other, first]
        )

        #expect(session.occurrence(of: first) == 0)
        #expect(session.occurrence(of: second) == 1)
        #expect(session.occurrence(of: other) == 0)
        #expect(session.exercise(templateId: library.id, occurrence: 0)?.id == "first")
        #expect(session.exercise(templateId: library.id, occurrence: 1)?.id == "second")
        #expect(session.exercise(templateId: library.id, occurrence: 2) == nil)
        #expect(session.exercise(templateId: library.id, occurrence: -1) == nil)
        #expect(session.exercise(templateId: "missing", occurrence: 0) == nil)
    }
}
