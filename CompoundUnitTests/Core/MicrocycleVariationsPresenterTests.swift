//
//  MicrocycleVariationsPresenterTests.swift
//  CompoundUnitTests
//
//  How a template exercise's targets vary by week: the summary line, and the screen that adds,
//  moves and deletes the overrides.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct MicrocycleVariationSummaryTests {

    private func sets(_ count: Int) -> [SetTarget] {
        (0..<count).map { SetTarget(setNumber: $0 + 1) }
    }

    @Test("Test Nothing Varies Without Overrides")
    func testNoOverrides() {
        #expect(SetTargetPlan.variationSummary(base: sets(2), overrides: []) == nil)
    }

    @Test("Test Consecutive Overrides Bound Each Other And The Last Runs On")
    func testSummary() {
        let summary = SetTargetPlan.variationSummary(base: sets(2), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3))
        ])

        #expect(summary == "Week 1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets")
    }

    @Test("Test A Base Of Several Weeks And A One-Week Override Read As Ranges")
    func testRanges() {
        let summary = SetTargetPlan.variationSummary(base: sets(3), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 5, setTargets: sets(1)),
            MicrocycleSetTargets(fromMicrocycle: 6, setTargets: sets(3))
        ])

        #expect(summary == "Weeks 1–4: 3 sets · Week 5: 1 set · From week 6: 3 sets")
    }

    @Test("Test An Override From Week 1 Replaces The Base")
    func testOverrideFromWeekOne() {
        let summary = SetTargetPlan.variationSummary(base: sets(3), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 1, setTargets: sets(2))
        ])

        #expect(summary == "From week 1: 2 sets")
    }

    @Test("Test Links Are Saved Only As Web Addresses")
    func testValidatedLink() {
        #expect(SetTargetPlan.validatedLink(" https://youtu.be/abc ") == "https://youtu.be/abc")
        #expect(SetTargetPlan.validatedLink("HTTP://example.com/x?y=1") == "HTTP://example.com/x?y=1")
        #expect(SetTargetPlan.validatedLink("example.com") == nil)
        #expect(SetTargetPlan.validatedLink("ftp://example.com") == nil)
        #expect(SetTargetPlan.validatedLink("https://") == nil)
        #expect(SetTargetPlan.validatedLink("javascript:alert(1)") == nil)
        #expect(SetTargetPlan.validatedLink("") == nil)
    }

    @Test("Test Rest Runs From 15 Seconds To 10 Minutes In 15 Second Steps")
    func testRestChoices() {
        let seconds = SetTargetPlan.restSecondsChoices.compactMap { $0 }

        #expect(SetTargetPlan.restSecondsChoices.first == .some(nil))
        #expect(seconds.first == 15 && seconds.last == 600 && seconds.count == 40)
        #expect(SetTargetPlan.choices(SetTargetPlan.restSecondsChoices, including: 50).compactMap { $0 }.contains(50))
        #expect(SetTargetPlan.choices(SetTargetPlan.warmupSetChoices, including: 5) == [nil, 0, 1, 2, 3, 4, 5])
        #expect(SetTargetPlan.choices(SetTargetPlan.warmupSetChoices, including: 2) == SetTargetPlan.warmupSetChoices)
    }
}

@MainActor
private final class VariationsInteractor: SpyGlobalInteractor, MicrocycleVariationsInteractor, SetTargetInteractor {
    var workoutSettings = WorkoutSettings(authorId: "user-1")
    var allExercises: [ExerciseModel] = []
}

@MainActor
private final class VariationsRouter: MicrocycleVariationsRouter, SetTargetRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var editors: [SetTargetDelegate] = []

    func showSetTargetView(delegate: SetTargetDelegate) { editors.append(delegate) }
    func showSetPlanDetailView(delegate: SetPlanDetailDelegate) { }
    func showExercisesPickerView(delegate: ExercisesPickerDelegate) { }
    func showMicrocycleVariationsView(delegate: MicrocycleVariationsDelegate) { }
}

@MainActor
struct MicrocycleVariationsPresenterTests {

    private final class Changes {
        var last: [MicrocycleSetTargets]?
    }

    private struct Screen {
        let presenter: MicrocycleVariationsPresenter
        let interactor: VariationsInteractor
        let router: VariationsRouter
        let changes: Changes
    }

    private func sets(_ count: Int, reps: Int = 8) -> [SetTarget] {
        (0..<count).map { SetTarget(setNumber: $0 + 1, minReps: reps, maxReps: reps) }
    }

    private func makeScreen(base: Int = 2, overrides: [MicrocycleSetTargets] = []) -> Screen {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.setTargets = sets(base)
        exercise.setTargetsByMicrocycle = overrides
        let changes = Changes()
        let interactor = VariationsInteractor()
        let router = VariationsRouter()
        let presenter = MicrocycleVariationsPresenter(
            interactor: interactor,
            router: router,
            delegate: MicrocycleVariationsDelegate(exercise: exercise) { changes.last = $0 }
        )
        return Screen(presenter: presenter, interactor: interactor, router: router, changes: changes)
    }

    @Test("Test The First Variation Starts At Week 2 As A Copy Of The Base With Fresh Sets")
    func testAddSeedsFromBase() throws {
        let screen = makeScreen(base: 2)
        let baseIds = Set(screen.presenter.targetsBinding(for: "none").wrappedValue.setTargets.map(\.id))
        #expect(screen.presenter.nextWeek == 2)

        screen.presenter.onAddVariationPressed()

        let added = try #require(screen.presenter.variations.first)
        #expect(added.fromMicrocycle == 2)
        #expect(added.setTargets.map(\.minReps) == [8, 8])
        #expect(Set(added.setTargets.map(\.id)).isDisjoint(with: baseIds))
        #expect(screen.changes.last?.map(\.fromMicrocycle) == [2])
        #expect(screen.interactor.trackedEventNames == ["MicrocycleVariationsView_AddVariation"])
    }

    @Test("Test The Next Variation Copies The Week Before It")
    func testAddSeedsFromPreviousOverride() {
        let screen = makeScreen(base: 2, overrides: [MicrocycleSetTargets(fromMicrocycle: 4, setTargets: sets(3, reps: 6))])

        screen.presenter.onAddVariationPressed()

        #expect(screen.presenter.variations.map(\.fromMicrocycle) == [4, 5])
        #expect(screen.presenter.variations[1].setTargets.map(\.minReps) == [6, 6, 6])
    }

    @Test("Test Past Week 52 The First Free Week Is Used, And None Once Every Week Is Taken")
    func testNextWeekWraps() {
        let screen = makeScreen(overrides: [MicrocycleSetTargets(fromMicrocycle: 52, setTargets: sets(1))])
        #expect(screen.presenter.nextWeek == 2)

        let full = makeScreen(overrides: (2...52).map { MicrocycleSetTargets(fromMicrocycle: $0, setTargets: sets(1)) })
        #expect(full.presenter.nextWeek == nil)
        #expect(!full.presenter.canAddVariation)
        full.presenter.onAddVariationPressed()
        #expect(full.presenter.variations.count == 51)
    }

    @Test("Test Overrides Arrive Sorted By Week")
    func testSorted() {
        let screen = makeScreen(overrides: [
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3))
        ])

        #expect(screen.presenter.variations.map(\.fromMicrocycle) == [2, 9])
        #expect(screen.presenter.weekTitle(screen.presenter.variations[1]) == "From week 9")
        #expect(screen.presenter.setsTitle(screen.presenter.variations[1]) == "4 sets")
    }

    @Test("Test A Week Cannot Step Onto Another Variation's Week Or Out Of 2 To 52")
    func testUniqueWeeks() {
        let screen = makeScreen(overrides: [
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(1)),
            MicrocycleSetTargets(fromMicrocycle: 3, setTargets: sets(1)),
            MicrocycleSetTargets(fromMicrocycle: 52, setTargets: sets(1))
        ])
        let variations = screen.presenter.variations

        #expect(!screen.presenter.canStep(variations[0], by: -1))
        #expect(!screen.presenter.canStep(variations[0], by: 1))
        #expect(!screen.presenter.canStep(variations[1], by: -1))
        #expect(screen.presenter.canStep(variations[1], by: 1))
        #expect(!screen.presenter.canStep(variations[2], by: 1))

        screen.presenter.onStep(variations[0], by: 1)
        #expect(screen.presenter.variations.map(\.fromMicrocycle) == [2, 3, 52])
        #expect(screen.changes.last == nil)

        screen.presenter.onStep(variations[1], by: 1)
        #expect(screen.presenter.variations.map(\.fromMicrocycle) == [2, 4, 52])
        #expect(screen.changes.last?.map(\.fromMicrocycle) == [2, 4, 52])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }

    @Test("Test Deleting A Variation Hands Back The Rest")
    func testDelete() {
        let screen = makeScreen(overrides: [
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3)),
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4))
        ])

        screen.presenter.onDeletePressed(screen.presenter.variations[0])

        #expect(screen.changes.last?.map(\.fromMicrocycle) == [9])
        #expect(screen.presenter.summary == "Weeks 1–8: 2 sets · From week 9: 4 sets")
    }

    @Test("Test The Summary Reads Every Range")
    func testSummary() {
        #expect(makeScreen().presenter.summary == "Same every week")

        let screen = makeScreen(overrides: [
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3)),
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4))
        ])
        #expect(screen.presenter.summary == "Week 1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets")
    }

    @Test("Test A Variation Opens The Set-Target Editor On Its Own Targets And Saves Back To It")
    func testEditingAWeek() throws {
        let screen = makeScreen(overrides: [MicrocycleSetTargets(fromMicrocycle: 3, setTargets: sets(2))])

        screen.presenter.onVariationPressed(screen.presenter.variations[0])
        let delegate = try #require(screen.router.editors.last)
        #expect(delegate.scope == .week(3))

        let editor = SetTargetPresenter(interactor: screen.interactor, router: screen.router, delegate: delegate)
        #expect(editor.title == "From week 3")
        #expect(editor.workingExercise.setTargets.count == 2)
        editor.onAddSetPressed()
        editor.onSavePressed()

        #expect(screen.presenter.variations[0].setTargets.count == 3)
        #expect(screen.changes.last?.first?.setTargets.count == 3)
    }

    @Test("Test Appearing Is Tracked")
    func testAppear() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["MicrocycleVariationsView_Appear"])
    }
}
