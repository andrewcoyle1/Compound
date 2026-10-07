//
//  DefineWorkoutPresenterTests.swift
//  CompoundUnitTests
//
//  The workout editor's supersets and plan line through its presenter, the screen both the
//  workout wizard and a mesocycle day host. The rules themselves are in `DefineWorkoutRulesTests`.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
struct DefineWorkoutPresenterTests {

    private final class Interactor: SpyGlobalInteractor, DefineWorkoutInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    private final class Router: DefineWorkoutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var setTargetDelegates: [SetTargetDelegate] = []

        func showExercisesPickerView(delegate: ExercisesPickerDelegate) { }
        func showSetTargetView(delegate: SetTargetDelegate) { setTargetDelegates.append(delegate) }
    }

    private final class Box {
        var value: [WorkoutTemplateExercise]
        init(_ value: [WorkoutTemplateExercise]) { self.value = value }
    }

    private struct Screen {
        let presenter: DefineWorkoutPresenter
        let interactor: Interactor
        let router: Router
        let box: Box
    }

    /// Exercises named by id, with the group each is in.
    private func makeScreen(_ entries: [(String, String?)]) -> Screen {
        let box = Box(entries.map { id, group in
            var exercise = WorkoutTemplateExercise(id: id, exercise: .mock, setRestTimers: false)
            exercise.supersetGroupId = group
            return exercise
        })
        let interactor = Interactor()
        let router = Router()
        let binding = Binding(
            get: { MainActor.assumeIsolated { box.value } },
            set: { newValue in MainActor.assumeIsolated { box.value = newValue } }
        )
        return Screen(
            presenter: DefineWorkoutPresenter(interactor: interactor, router: router, exercises: binding),
            interactor: interactor,
            router: router,
            box: box
        )
    }

    @Test("Test An Exercise Opens The Targets Editor With Its Plan")
    func testExerciseOpensWithPlan() {
        let screen = makeScreen([("a", nil)])

        screen.presenter.onExercisePressed(exercise: .constant(screen.presenter.exercises[0]))

        #expect(screen.router.setTargetDelegates.map(\.scope) == [.template])
    }

    @Test("Test Choosing Two Exercises Makes A Superset Lettered A, Reaching The Parent")
    func testSupersetSelection() {
        let screen = makeScreen([("a", nil), ("b", nil), ("c", nil)])
        #expect(screen.presenter.canStartSuperset)

        screen.presenter.onSupersetPressed()
        #expect(screen.presenter.isSelectingSuperset)
        screen.presenter.onSupersetRowPressed(screen.presenter.exercises[0])
        #expect(!screen.presenter.canConfirmSuperset)
        screen.presenter.onSupersetRowPressed(screen.presenter.exercises[2])
        #expect(screen.presenter.isSelectedForSuperset(screen.presenter.exercises[2]))
        screen.presenter.onSupersetConfirmPressed()

        #expect(!screen.presenter.isSelectingSuperset)
        #expect(screen.box.value.map(\.id) == ["a", "c", "b"])
        #expect(screen.box.value[0].supersetGroupId != nil)
        #expect(screen.box.value[0].supersetGroupId == screen.box.value[1].supersetGroupId)
        #expect(screen.presenter.exercises.map { screen.presenter.supersetLetter(for: $0) } == ["A", "A", nil])
        #expect(screen.presenter.supersetAccessibilityLabel(letter: "A") == "Superset A")
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection", "success"])
        #expect(screen.interactor.trackedEventNames == ["DefineWorkoutView_Superset_Created"])
    }

    @Test("Test A Single Exercise Cannot Start A Superset")
    func testSupersetNeedsTwo() {
        let screen = makeScreen([("a", nil)])

        screen.presenter.onSupersetPressed()

        #expect(!screen.presenter.canStartSuperset)
        #expect(!screen.presenter.isSelectingSuperset)
    }

    @Test("Test Cancelling Superset Selection Changes Nothing")
    func testSupersetCancel() {
        let screen = makeScreen([("a", nil), ("b", nil)])

        screen.presenter.onSupersetPressed()
        screen.presenter.onSupersetRowPressed(screen.presenter.exercises[0])
        screen.presenter.onSupersetRowPressed(screen.presenter.exercises[1])
        screen.presenter.onSupersetCancelPressed()

        #expect(!screen.presenter.isSelectingSuperset)
        #expect(screen.box.value.allSatisfy { $0.supersetGroupId == nil })
    }

    @Test("Test Removing Or Deleting A Member Of Two Dissolves The Superset")
    func testSupersetDissolves() {
        let grouped: [(String, String?)] = [("a", "g"), ("b", "g"), ("c", nil)]

        let removed = makeScreen(grouped)
        removed.presenter.onRemoveFromSupersetPressed(removed.presenter.exercises[0])
        #expect(removed.box.value.allSatisfy { $0.supersetGroupId == nil })
        #expect(removed.interactor.trackedEventNames == ["DefineWorkoutView_Superset_Removed"])

        let deleted = makeScreen(grouped)
        deleted.presenter.removeExercise(exercise: deleted.presenter.exercises[1])
        #expect(deleted.box.value.map(\.id) == ["a", "c"])
        #expect(deleted.box.value.allSatisfy { $0.supersetGroupId == nil })

        let swiped = makeScreen(grouped)
        swiped.presenter.deleteExercises(at: [0])
        #expect(swiped.box.value.allSatisfy { $0.supersetGroupId == nil })
    }

    @Test("Test Moving A Member Moves Its Superset")
    func testMoveKeepsGroup() {
        let screen = makeScreen([("a", "g"), ("b", "g"), ("c", nil)])

        screen.presenter.moveExercises(from: [0], to: 3)

        #expect(screen.box.value.map(\.id) == ["c", "a", "b"])
    }

    @Test("Test A Row Names Its Plan")
    func testRowPlanSummary() {
        let screen = makeScreen([("a", nil)])
        screen.presenter.exercises[0].warmupSetCount = 2

        #expect(screen.presenter.planSummary(for: screen.presenter.exercises[0]) == "2 warm-ups")
        #expect(screen.box.value[0].warmupSetCount == 2)
    }
}
