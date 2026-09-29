//
//  CreateExerciseFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Shared scaffolding

/// A mutable value reachable through a `Binding`. `Binding`'s accessors are `@Sendable`, so the
/// box has to be main-actor isolated and reached through `assumeIsolated`.
@MainActor
private final class MetricBox {
    var value: TrackableExerciseMetric?
    var binding: Binding<TrackableExerciseMetric?> {
        Binding(
            get: { MainActor.assumeIsolated { self.value } },
            set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
        )
    }
}

/// What an enum picker was opened with, recorded rather than shown.
private struct RecordedEnumPicker {
    let title: String
    let canDelete: Bool
    let detents: PresentationDetentTransformable?
}

// MARK: - Add Training

/// The sheet behind the "+" button in Training, offering a program, a workout or an exercise.
///
/// It owns no state: each row dismisses the sheet and calls back to whoever presented it, so the
/// only thing it can get wrong is wiring a row to the wrong callback and dropping the user into
/// the wrong builder. `dismissScreen()` is a `GlobalRouter` extension method this screen's router
/// does not restate, so it is statically dispatched and invisible to a double — the callbacks are
/// what these tests watch.
@MainActor
struct AddTrainingPresenterTests {

    private final class Interactor: SpyGlobalInteractor, AddTrainingInteractor { }

    private final class Router: AddTrainingRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showCreateProgramView(delegate: CreateProgramDelegate) { }
        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) { }
    }

    /// Records which of the three callbacks fired, in order.
    private final class Choices {
        var made: [String] = []
    }

    private func makeScreen(delegate: AddTrainingDelegate) -> (AddTrainingPresenter, Interactor) {
        let interactor = Interactor()
        return (AddTrainingPresenter(interactor: interactor, router: Router(), delegate: delegate), interactor)
    }

    @Test("Test Each Row Starts The Builder It Names")
    func testEachRowStartsTheBuilderItNames() {
        let choices = Choices()
        let (presenter, _) = makeScreen(delegate: AddTrainingDelegate(
            onSelectProgram: { choices.made.append("program") },
            onSelectWorkout: { choices.made.append("workout") },
            onSelectExercise: { choices.made.append("exercise") }
        ))
        presenter.onNewProgramPressed()
        presenter.onNewEmptyWorkoutPressed()
        presenter.onNewExercisePressed()
        #expect(choices.made == ["program", "workout", "exercise"])
    }

    /// All three callbacks are optional, and a caller offering only one of them must not bring the
    /// app down when the user taps another row.
    @Test("Test A Row Without A Callback Does Nothing")
    func testARowWithoutACallbackDoesNothing() {
        let (presenter, _) = makeScreen(delegate: AddTrainingDelegate())
        presenter.onNewProgramPressed()
        presenter.onNewEmptyWorkoutPressed()
        presenter.onNewExercisePressed()
        presenter.dismissScreen()
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makeScreen(delegate: AddTrainingDelegate())
        presenter.onViewAppear()
        presenter.onViewDisappear()
        #expect(interactor.trackedScreenEventNames == ["AddTrainingView_Appear"])
        #expect(interactor.trackedEventNames == ["AddTrainingView_Disappear"])
    }
}

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
        private(set) var pickers: [RecordedEnumPicker] = []
        private(set) var metricBindings: [Binding<TrackableExerciseMetric?>] = []
        private(set) var muscleGroupDelegates: [MuscleGroupPickerDelegate] = []

        func showDevSettingsView() { }

        func showEnumPickerView<Item: PickableItem>(
            delegate: EnumPickerDelegate<Item>,
            detentsInput: PresentationDetentTransformable?
        ) {
            pickers.append(RecordedEnumPicker(title: delegate.navigationTitle, canDelete: delegate.canDelete, detents: detentsInput))
            if let metricDelegate = delegate as? EnumPickerDelegate<TrackableExerciseMetric> {
                metricBindings.append(metricDelegate.chosenItem)
            }
        }

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

    /// A metric can be cleared again, but a chosen exercise type or laterality cannot be
    /// un-chosen, so only the metric pickers offer delete.
    @Test("Test Only The Metric Pickers Can Be Cleared")
    func testOnlyTheMetricPickersCanBeCleared() {
        let screen = makeScreen()
        screen.presenter.trackableMetricPressed(navigationTitle: "Trackable Metric 1", metric: MetricBox().binding)
        screen.presenter.exerciseTypePressed(navigationTitle: "Exercise Type", type: .constant(nil))
        screen.presenter.lateralityPressed(navigationTitle: "Laterality", item: .constant(nil))
        #expect(screen.router.pickers.map(\.title) == ["Trackable Metric 1", "Exercise Type", "Laterality"])
        #expect(screen.router.pickers.map(\.canDelete) == [true, false, false])
        #expect(screen.router.pickers.map(\.detents) == [nil, .medium, .medium])
    }

    /// The picker writes back through the binding it was handed. Hand over the wrong one and the
    /// user's choice lands nowhere.
    @Test("Test A Picked Metric Lands In The Field It Came From")
    func testAPickedMetricLandsInTheFieldItCameFrom() {
        let screen = makeScreen()
        let box = MetricBox()
        screen.presenter.trackableMetricPressed(navigationTitle: "Trackable Metric 1", metric: box.binding)
        screen.router.metricBindings.first?.wrappedValue = .repsPerSide
        #expect(box.value == .repsPerSide)
    }

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

// MARK: - Enum picker

@MainActor
struct EnumPickerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, EnumPickerInteractor { }

    private final class Router: EnumPickerRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @MainActor
    private final class Choice {
        var value: TrackableExerciseMetric?

        var binding: Binding<TrackableExerciseMetric?> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    @Test("Test Choosing An Option Writes It Back And Plays The Selection Haptic")
    func testChoosingAnOptionWritesItBackAndPlaysTheSelectionHaptic() {
        let interactor = Interactor()
        let presenter = EnumPickerPresenter(interactor: interactor, router: Router())
        let choice = Choice()

        presenter.onSelect(item: TrackableExerciseMetric.reps, binding: choice.binding)

        #expect(choice.value == .reps)
        #expect(interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }
}
