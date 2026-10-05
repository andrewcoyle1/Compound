//
//  CreateExerciseFlowPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

// MARK: - Create Exercise

/// Step one of building a custom exercise: its name, the one or two metrics it is logged against,
/// and optionally its type and laterality.
///
/// Nothing is saved here. The risk is the gate — an exercise with no name or no metric is unusable
/// downstream — and the delegate opening the next step, which is assembled field by field.
@MainActor
struct CreateExercisePresenterTests {

    private final class Interactor: SpyGlobalInteractor, CreateExerciseInteractor { }

    /// `showDevSettingsView()` is declared unguarded: the test target builds without `-DDEV`, so a
    /// double that guards it the way the router does would not satisfy the protocol.
    private final class Router: CreateExerciseRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var muscleGroupDelegates: [MuscleGroupPickerDelegate] = []

        func showDevSettingsView() { }

        func showMuscleGroupPickerView(delegate: MuscleGroupPickerDelegate) {
            muscleGroupDelegates.append(delegate)
        }

        private(set) var dialogTitles: [String] = []
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            dialogTitles.append(title)
        }
    }

    /// Close on a blank form leaves at once; once anything is typed or picked it asks first.
    @Test("Test Closing After Typing Asks Before Discarding")
    func testClosingAfterTypingAsksBeforeDiscarding() {
        let blank = makeScreen()
        blank.presenter.exerciseName = "   "
        blank.presenter.onCancelPressed()
        #expect(blank.router.dialogTitles.isEmpty)

        let filled = makeScreen()
        filled.presenter.laterality = .unilateral
        filled.presenter.onCancelPressed()
        #expect(filled.router.dialogTitles == ["Discard Changes?"])
    }

    private struct Screen {
        let presenter: CreateExercisePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(presenter: CreateExercisePresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    /// A screen filled in the way a user would have left it, with the name padded the way a
    /// keyboard leaves it.
    private func filledScreen() -> Screen {
        let screen = makeScreen()
        screen.presenter.exerciseName = "  Bench Press  "
        screen.presenter.trackableMetricA = .reps
        screen.presenter.trackableMetricB = .weight
        screen.presenter.exerciseType = .compoundUpper
        screen.presenter.laterality = .bilateral
        return screen
    }

    /// An exercise with no trackable metric has nothing to log against it, so it is not usable
    /// however well named; and a name of nothing but spaces is not a name.
    @Test("Test A Name And A Metric Are Both Required")
    func testANameAndAMetricAreBothRequired() {
        let noName = makeScreen()
        noName.presenter.exerciseName = "   "
        noName.presenter.trackableMetricA = .reps
        #expect(!noName.presenter.canSave)

        let noMetric = makeScreen()
        noMetric.presenter.exerciseName = "Bench Press"
        #expect(!noMetric.presenter.canSave)
    }

    @Test("Test The Second Metric Alone Is Enough To Continue")
    func testTheSecondMetricAloneIsEnoughToContinue() {
        let screen = makeScreen()
        screen.presenter.exerciseName = "Bench Press"
        screen.presenter.trackableMetricB = .weight
    }

    @Test("Test Nothing Opens Until The Gate Is Passed")
    func testNothingOpensUntilTheGateIsPassed() {
        let noName = makeScreen()
        noName.presenter.trackableMetricA = .reps
        noName.presenter.onNextPressed()
        #expect(noName.router.muscleGroupDelegates.isEmpty)

        let noMetric = makeScreen()
        noMetric.presenter.exerciseName = "Bench Press"
        noMetric.presenter.onNextPressed()
        #expect(noMetric.router.muscleGroupDelegates.isEmpty)
    }

    /// The next step's delegate insists on a first metric, so filling only the second box has to be
    /// promoted rather than dropped — otherwise the user picks a metric and Next appears to do
    /// nothing at all.
    @Test("Test Filling Only The Second Metric Promotes It To The First")
    func testFillingOnlyTheSecondMetricPromotesItToTheFirst() {
        let screen = makeScreen()
        screen.presenter.exerciseName = "Plank"
        screen.presenter.trackableMetricB = .duration
        screen.presenter.onNextPressed()
        #expect(screen.presenter.trackableMetricA == .duration)
        #expect(screen.presenter.trackableMetricB == nil)
        #expect(screen.router.muscleGroupDelegates.first?.trackableMetricA == .duration)
        #expect(screen.router.muscleGroupDelegates.first?.trackableMetricB == nil)
    }

    @Test("Test The Typed Fields Reach The Muscle Group Step")
    func testTheTypedFieldsReachTheMuscleGroupStep() {
        let screen = filledScreen()
        screen.presenter.onNextPressed()
        let delegate = screen.router.muscleGroupDelegates.first
        #expect(delegate?.name == "Bench Press")
        #expect(delegate?.trackableMetricA == .reps)
        #expect(delegate?.trackableMetricB == .weight)
        #expect(delegate?.exerciseType == .compoundUpper)
        #expect(delegate?.laterality == .bilateral)
    }

    /// Type and laterality are both optional, and leaving them alone must carry nothing rather than
    /// inventing a default the user never chose.
    @Test("Test The Optional Details Are Carried As Unset")
    func testTheOptionalDetailsAreCarriedAsUnset() {
        let screen = makeScreen()
        screen.presenter.exerciseName = "Bench Press"
        screen.presenter.trackableMetricA = .reps
        screen.presenter.onNextPressed()
        #expect(screen.router.muscleGroupDelegates.first?.exerciseType == nil)
        #expect(screen.router.muscleGroupDelegates.first?.laterality == nil)
    }

    // The metric, type and laterality sheets became in-row menu pickers bound straight to these
    // fields, so the tests of what each sheet was opened with went with them.

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()
        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()
        #expect(screen.interactor.trackedScreenEventNames == ["CreateExerciseView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["CreateExerciseView_Disappear"])
    }
}

// MARK: - Muscle Group Picker

/// Step two: which muscles the exercise trains, and how hard.
///
/// Each muscle is a three-state control rather than a checkbox — untouched, primary, secondary —
/// and the cycle has to come back round to untouched or a mis-tap can never be undone. The step is
/// also skippable, so it must be able to hand on an empty selection.
@MainActor
struct MuscleGroupPickerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MuscleGroupPickerInteractor { }

    private final class Router: MuscleGroupPickerRouter {
        private(set) var equipmentDelegates: [ExerciseEquipmentDelegate] = []
        func showExerciseEquipmentView(delegate: ExerciseEquipmentDelegate) {
            equipmentDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: MuscleGroupPickerPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(presenter: MuscleGroupPickerPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private func delegate() -> MuscleGroupPickerDelegate {
        MuscleGroupPickerDelegate(
            name: "Bench Press",
            trackableMetricA: .reps,
            trackableMetricB: .weight,
            exerciseType: .compoundUpper,
            laterality: .bilateral
        )
    }

    /// The screen shows two lists and nothing else, so every muscle has to appear in exactly one of
    /// them or it is unreachable.
    @Test("Test Every Muscle Appears In Exactly One Section")
    func testEveryMuscleAppearsInExactlyOneSection() {
        let presenter = makeScreen().presenter
        let upper = Set(presenter.upperMuscles)
        let lower = Set(presenter.lowerMuscles)
        #expect(upper.isDisjoint(with: lower))
        #expect(upper.union(lower) == Set(Muscles.allCases))
    }

    @Test("Test Pressing A Muscle Cycles Primary Secondary And Off")
    func testPressingAMuscleCyclesPrimarySecondaryAndOff() {
        let screen = makeScreen()
        let presenter = screen.presenter
        presenter.onMuscleGroupPressed(muscle: .chest)
        #expect(presenter.selectedMuscleGroups[.chest] == .primary)
        presenter.onMuscleGroupPressed(muscle: .chest)
        #expect(presenter.selectedMuscleGroups[.chest] == .secondary)
        presenter.onMuscleGroupPressed(muscle: .chest)
        #expect(presenter.selectedMuscleGroups[.chest] == nil)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection", "selection"])
    }

    /// The footer counts what has been chosen, and the two weights are counted separately.
    @Test("Test The Counts Split Primary From Secondary")
    func testTheCountsSplitPrimaryFromSecondary() {
        let presenter = makeScreen().presenter
        presenter.onMuscleGroupPressed(muscle: .chest)
        presenter.onMuscleGroupPressed(muscle: .triceps)
        presenter.onMuscleGroupPressed(muscle: .triceps)
        presenter.onMuscleGroupPressed(muscle: .frontDelts)
        presenter.onMuscleGroupPressed(muscle: .frontDelts)
        #expect(presenter.primaryCount == 1)
        #expect(presenter.secondaryCount == 2)
    }

    @Test("Test Reset Clears Every Selection")
    func testResetClearsEverySelection() {
        let presenter = makeScreen().presenter
        presenter.onMuscleGroupPressed(muscle: .chest)
        presenter.onMuscleGroupPressed(muscle: .quads)
        presenter.onResetPressed()
        #expect(presenter.selectedMuscleGroups.isEmpty)
    }

    @Test("Test The Chosen Muscles And Everything Before Them Reach The Equipment Step")
    func testTheChosenMusclesAndEverythingBeforeThemReachTheEquipmentStep() {
        let screen = makeScreen()
        screen.presenter.onMuscleGroupPressed(muscle: .chest)
        screen.presenter.onMuscleGroupPressed(muscle: .triceps)
        screen.presenter.onMuscleGroupPressed(muscle: .triceps)
        screen.presenter.onNextPressed(delegate: delegate())
        let passed = screen.router.equipmentDelegates.first
        #expect(passed?.name == "Bench Press")
        #expect(passed?.trackableMetricA == .reps)
        #expect(passed?.trackableMetricB == .weight)
        #expect(passed?.exerciseType == .compoundUpper)
        #expect(passed?.laterality == .bilateral)
        #expect(passed?.muscleGroups == [.chest: .primary, .triceps: .secondary])
    }

    /// The button reads "Skip" when nothing is chosen, so continuing with an empty selection is a
    /// supported route rather than a dead end.
    @Test("Test The Step Can Be Skipped Entirely")
    func testTheStepCanBeSkippedEntirely() {
        let screen = makeScreen()
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.equipmentDelegates.first?.muscleGroups.isEmpty == true)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()
        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()
        #expect(screen.interactor.trackedScreenEventNames == ["MuscleGroupPickerView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["MuscleGroupPickerView_Disappear"])
    }
}
