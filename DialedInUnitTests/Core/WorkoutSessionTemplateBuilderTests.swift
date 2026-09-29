//
//  WorkoutSessionTemplateBuilderTests.swift
//  DialedInUnitTests
//
//  Saving a feed card as a template: which exercises survive, what set targets they carry, and
//  what the template is called.
//

import Testing
@testable import DialedIn

/// Shared by the builder suite and the row's save-as-template suite.
@MainActor
enum SaveTemplateFixture {

    static func libraryExercise(id: String, name: String) -> ExerciseModel {
        var exercise = ExerciseModel.mock
        exercise.id = id
        exercise.name = name
        return exercise
    }

    static func set(_ index: Int, reps: Int?, side: SetSide? = nil, isWarmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(side?.rawValue ?? "both")",
            authorId: "friend",
            index: index,
            reps: reps,
            weightKg: 60,
            side: side,
            isWarmup: isWarmup,
            completedAt: DashboardFixture.date(day: 2),
            dateCreated: DashboardFixture.date(day: 2)
        )
    }

    static func logged(_ name: String, templateId: String, index: Int, sets: [WorkoutSetModel]? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "logged-\(index)",
            authorId: "friend",
            templateId: templateId,
            name: name,
            trackingMode: .weightReps,
            index: index,
            sets: sets ?? [set(1, reps: 10)]
        )
    }

    static func session(name: String = "Push Day", exercises: [WorkoutExerciseModel]) -> WorkoutSessionModel {
        DashboardFixture.session(id: "session-x", author: "friend", name: name, on: DashboardFixture.date(day: 2), exercises: exercises)
    }
}

@MainActor
struct WorkoutSessionTemplateBuilderTests {

    private typealias Fixture = SaveTemplateFixture

    private func build(
        _ session: WorkoutSessionModel,
        library: [ExerciseModel],
        existingNames: [String] = []
    ) -> WorkoutTemplateModel? {
        WorkoutSessionTemplateBuilder.template(from: session, availableExercises: library, existingNames: existingNames, authorId: "me")
    }

    @Test("Test Exercises Resolve By Id Then By Name And Unresolved Ones Are Skipped")
    func testExercisesResolveByIdThenByNameAndUnresolvedOnesAreSkipped() {
        let bench = Fixture.libraryExercise(id: "system-bench", name: "Bench Press")
        let myRow = Fixture.libraryExercise(id: "my-row", name: "Cable Row")
        // The id wins even when the name disagrees, so a renamed exercise still resolves.
        let session = Fixture.session(exercises: [
            Fixture.logged("Flat Bench", templateId: "system-bench", index: 1),
            Fixture.logged("Mystery Lift", templateId: "friend-only", index: 2),
            Fixture.logged(" cable row", templateId: "friends-cable-row", index: 3)
        ])

        let template = build(session, library: [myRow, bench])

        #expect(template?.exercises.map { $0.exercise.id } == ["system-bench", "my-row"])
        #expect(template?.authorId == "me")
        #expect(template?.name == "Push Day")
    }

    @Test("Test Exercises Keep The Session Order")
    func testExercisesKeepTheSessionOrder() {
        let first = Fixture.libraryExercise(id: "a", name: "A")
        let second = Fixture.libraryExercise(id: "b", name: "B")
        let session = Fixture.session(exercises: [
            Fixture.logged("B", templateId: "b", index: 2),
            Fixture.logged("A", templateId: "a", index: 1)
        ])

        #expect(build(session, library: [second, first])?.exercises.map { $0.exercise.id } == ["a", "b"])
    }

    @Test("Test Set Targets Reflect Working Sets Only")
    func testSetTargetsReflectWorkingSetsOnly() {
        let bench = Fixture.libraryExercise(id: "bench", name: "Bench Press")
        let session = Fixture.session(exercises: [
            Fixture.logged("Bench Press", templateId: "bench", index: 1, sets: [
                Fixture.set(1, reps: 12, isWarmup: true),
                Fixture.set(2, reps: 10),
                Fixture.set(3, reps: 8),
                Fixture.set(4, reps: 6)
            ])
        ])

        let targets = build(session, library: [bench])?.exercises.first?.setTargets ?? []

        #expect(targets.map(\.setNumber) == [1, 2, 3])
        #expect(targets.map(\.minReps) == [10, 8, 6])
        #expect(targets.map(\.maxReps) == [10, 8, 6])
    }

    @Test("Test A Left And Right Pair Is One Set Target")
    func testALeftAndRightPairIsOneSetTarget() {
        let row = Fixture.libraryExercise(id: "row", name: "Single Arm Row")
        let session = Fixture.session(exercises: [
            Fixture.logged("Single Arm Row", templateId: "row", index: 1, sets: [
                Fixture.set(1, reps: 12, side: .left),
                Fixture.set(1, reps: 12, side: .right),
                Fixture.set(2, reps: 10, side: .left),
                Fixture.set(2, reps: 10, side: .right)
            ])
        ])

        let targets = build(session, library: [row])?.exercises.first?.setTargets ?? []

        #expect(targets.map(\.minReps) == [12, 10])
    }

    @Test("Test An Exercise With Only Warmups Gets One Default Target")
    func testAnExerciseWithOnlyWarmupsGetsOneDefaultTarget() {
        let bench = Fixture.libraryExercise(id: "bench", name: "Bench Press")
        let session = Fixture.session(exercises: [
            Fixture.logged("Bench Press", templateId: "bench", index: 1, sets: [Fixture.set(1, reps: 5, isWarmup: true)])
        ])

        let targets = build(session, library: [bench])?.exercises.first?.setTargets ?? []

        #expect(targets.count == 1)
        #expect(targets.first?.minReps == nil)
    }

    @Test("Test The Name Gets Copy Only On A Clash")
    func testTheNameGetsCopyOnlyOnAClash() {
        let bench = Fixture.libraryExercise(id: "bench", name: "Bench Press")
        let session = Fixture.session(name: "Push Day", exercises: [Fixture.logged("Bench Press", templateId: "bench", index: 1)])

        #expect(build(session, library: [bench], existingNames: ["Pull Day"])?.name == "Push Day")
        #expect(build(session, library: [bench], existingNames: ["push day"])?.name == "Push Day (copy)")
    }

    @Test("Test A Session With No Resolvable Exercise Builds Nothing")
    func testASessionWithNoResolvableExerciseBuildsNothing() {
        let session = Fixture.session(exercises: [Fixture.logged("Mystery Lift", templateId: "friend-only", index: 1)])

        #expect(build(session, library: [Fixture.libraryExercise(id: "bench", name: "Bench Press")]) == nil)
    }
}
