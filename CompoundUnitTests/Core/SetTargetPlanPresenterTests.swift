//
//  SetTargetPlanPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
private final class PlanInteractor: SpyGlobalInteractor, SetTargetInteractor {
    var workoutSettings = WorkoutSettings(authorId: "user-1")
}

@MainActor
private final class PlanRouter: SetTargetRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var details: [SetPlanDetailDelegate] = []

    func showSetPlanDetailView(delegate: SetPlanDetailDelegate) { details.append(delegate) }
    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
}

@MainActor
private final class PlanExerciseBox {
    var value: WorkoutTemplateExercise

    init(_ setTargets: [SetTarget]) {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.setTargets = setTargets
        value = exercise
    }

    var binding: Binding<WorkoutTemplateExercise> {
        Binding(
            get: { MainActor.assumeIsolated { self.value } },
            set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
        )
    }
}

/// The template editor with Workout Settings › Set Plan: the kind and plan under each set, and the
/// sheet that edits one set's plan.
@MainActor
struct SetTargetPlanPresenterTests {

    private struct Screen {
        let editor: SetTargetPresenter
        let interactor: PlanInteractor
        let router: PlanRouter
        let box: PlanExerciseBox
    }

    private func makeScreen(plansSets: Bool = true, _ setTargets: [SetTarget] = [SetTarget(id: "s1", setNumber: 1, minReps: 8, maxReps: 8)]) -> Screen {
        let interactor = PlanInteractor()
        interactor.workoutSettings.setPlanning = plansSets
        let router = PlanRouter()
        let box = PlanExerciseBox(setTargets)
        let editor = SetTargetPresenter(interactor: interactor, router: router, delegate: SetTargetDelegate(exercise: box.binding))
        return Screen(editor: editor, interactor: interactor, router: router, box: box)
    }

    /// Opens the first set's plan the way the row does, and returns the sheet's presenter.
    private func openDetail(_ screen: Screen, set index: Int = 0) throws -> SetPlanDetailPresenter {
        screen.editor.onSetPlanPressed(screen.editor.workingExercise.setTargets[index])
        let delegate = try #require(screen.router.details.last)
        return SetPlanDetailPresenter(interactor: screen.interactor, router: screen.router, delegate: delegate)
    }

    // MARK: - The editor

    @Test("Test The Editor Follows The Switch")
    func testTheEditorFollowsTheSwitch() {
        #expect(makeScreen(plansSets: true).editor.plansSets)
        #expect(!makeScreen(plansSets: false).editor.plansSets)
    }

    @Test("Test A Row Names Its Set And Kind For VoiceOver")
    func testRowAccessibility() {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 3, setType: .drop, dropCount: 2)])
        let target = screen.editor.workingExercise.setTargets[0]

        #expect(screen.editor.planAccessibilityLabel(for: target) == "Set 3, set type, Drop set")
        #expect(screen.editor.planChip(for: target) == "Drop set")
        #expect(screen.editor.planSummary(for: target) == "−20% ×2 to failure")
    }

    @Test("Test Tapping A Row Opens That Set's Plan")
    func testTappingARowOpensThePlan() {
        let screen = makeScreen()

        screen.editor.onSetPlanPressed(screen.editor.workingExercise.setTargets[0])

        #expect(screen.router.details.map(\.setTarget.id) == ["s1"])
    }

    // MARK: - The detail, round trips

    @Test("Test Choosing Drop Set Starts With Two Drops And Saves Each Field")
    func testDropRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .drop
        #expect(detail.dropCount == 2)
        #expect(screen.editor.hasUnsavedChanges)

        detail.dropCount = 3
        detail.onDropStepPressed(30)
        detail.dropReps = 6
        screen.editor.onSavePressed()

        let saved = screen.box.value.setTargets[0]
        #expect(saved.setType == .drop)
        #expect(saved.dropCount == 3)
        #expect(saved.dropStepPercent == 30)
        #expect(saved.dropReps == 6)
        #expect(saved.minReps == 8 && saved.maxReps == 8)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
    }

    @Test("Test Clearing The Drop Reps Goes Back To Failure")
    func testClearingDropReps() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .drop, dropCount: 2, dropReps: 6)])
        let detail = try openDetail(screen)

        detail.dropReps = nil

        #expect(screen.editor.workingExercise.setTargets[0].dropReps == nil)
    }

    @Test("Test Mini-Sets Are Saved For Each Kind That Takes Them", arguments: [SetTargetSetType.myo, .restPause, .cluster])
    func testMiniSetRoundTrip(kind: SetTargetSetType) throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = kind
        #expect(detail.miniSetCount == 3)
        #expect(detail.showsMiniSets && !detail.showsDrops && !detail.showsAMRAPTarget)
        detail.miniSetCount = 5
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == kind)
        #expect(screen.box.value.setTargets[0].miniSetCount == 5)
    }

    @Test("Test An AMRAP Target Starts From The Set's Reps And Is Saved")
    func testAMRAPRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .amrap
        #expect(detail.amrapTargetReps == 8)
        detail.amrapTargetReps = 10
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == .amrap)
        #expect(screen.box.value.setTargets[0].amrapTargetReps == 10)
    }

    // MARK: WP-P2

    @Test("Test Partials Start To Failure And Save Their Reps")
    func testPartialsRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .partials
        #expect(detail.showsPartialReps && !detail.showsHoldSeconds && !detail.showsDrops)
        #expect(detail.partialReps == nil)
        #expect(detail.partialRepsChoices == [nil] + Array(1...10).map(Optional.some))
        #expect(detail.partialRepsTitle(nil) == "To failure")
        #expect(detail.partialRepsTitle(5) == "5 reps")
        detail.partialReps = 5
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == .partials)
        #expect(screen.box.value.setTargets[0].partialReps == 5)
    }

    @Test("Test A Stretch Or Hold Starts At 30 Seconds And Saves Its Time", arguments: [SetTargetSetType.stretch, .hold])
    func testHoldSecondsRoundTrip(kind: SetTargetSetType) throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = kind
        #expect(detail.showsHoldSeconds && !detail.showsPartialReps)
        #expect(detail.holdSeconds == 30)
        #expect(detail.holdSecondsChoices == [15, 20, 30, 45, 60])
        #expect(detail.holdSecondsTitle(45) == "45 s")
        detail.holdSeconds = 45
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == kind)
        #expect(screen.box.value.setTargets[0].holdSeconds == 45)
    }

    /// An imported plan's 40 s hold is not one of the choices, but still shows as chosen.
    @Test("Test A Hold Time Outside The Choices Is Offered Too")
    func testUnlistedHoldSeconds() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .hold, holdSeconds: 40)])
        let detail = try openDetail(screen)

        #expect(detail.holdSecondsChoices == [15, 20, 30, 40, 45, 60])
    }

    @Test("Test A Typed Target That Is Not A Count Is No Target")
    func testBadTarget() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .amrap, amrapTargetReps: 8)])
        let detail = try openDetail(screen)

        detail.amrapTargetReps = 0
        #expect(detail.amrapTargetReps == nil)
        detail.amrapTargetReps = 9.6
        #expect(detail.amrapTargetReps == 10)
        detail.amrapTargetReps = .infinity
        #expect(detail.amrapTargetReps == nil)
    }

    /// Templates saved before AMRAP existed called it a failure set.
    @Test("Test A Legacy Failure Set Shows As AMRAP And Is Written As AMRAP On Edit")
    func testFailureBecomesAMRAP() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .failure)])
        let detail = try openDetail(screen)

        #expect(detail.setType == .amrap)
        #expect(!screen.editor.hasUnsavedChanges)

        detail.amrapTargetReps = 8
        #expect(screen.editor.workingExercise.setTargets[0].setType == .amrap)
    }

    @Test("Test Picking The Kind Already Chosen Changes Nothing")
    func testSameKind() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .standard

        #expect(!screen.editor.hasUnsavedChanges)
        #expect(screen.interactor.playedHaptics.isEmpty)
    }

    @Test("Test Cancelling After A Plan Edit Asks First")
    func testCancelAfterPlanEdit() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .drop
        screen.editor.onClosePressed()

        #expect(screen.box.value.setTargets[0].setType == .standard)
        #expect(screen.editor.hasUnsavedChanges)
    }

    @Test("Test The Sheet Names Its Set And Tracks Its Appearance")
    func testSheetTitleAndAppearance() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["SetPlanDetailView_Appear"])
        #expect(detail.title == "Set 1")
        #expect(detail.setTypeAccessibilityLabel == "Set 1, set type")
    }
}
