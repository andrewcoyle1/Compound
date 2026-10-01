//
//  SetKeyboardPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The weight and reps keyboards: every key writes into the set as it is pressed, Next and Prev
/// move between the two fields, and Done offers to log a set that is ready.
@MainActor
struct SetKeyboardPresenterTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(weightKg: Double? = 60, reps: Int? = nil, done: Bool = false) -> GymEquipmentBox<WorkoutSetModel> {
        GymEquipmentBox(WorkoutSetModel(
            id: "s1", authorId: "u", index: 0, reps: reps, weightKg: weightKg,
            isWarmup: false, completedAt: done ? start : nil, dateCreated: start
        ))
    }

    private func type(_ keys: String, into keyboard: SetKeyboardPresenter) {
        keys.forEach { keyboard.type($0) }
    }

    // MARK: - Typing

    @Test func firstKeyReplacesAndEveryKeyWritesLive() {
        let box = set(weightKg: 60)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        #expect(keyboard.text == "60")

        keyboard.type("1")
        #expect(box.value.weightKg == 1)
        type("02.5", into: keyboard)
        #expect(box.value.weightKg == 102.5)
        #expect(keyboard.displayText(for: .weight, set: box.value, unit: .kilograms) == "102.5")
    }

    @Test func poundsAreStoredAsKilograms() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext(unit: .pounds))
        type("225", into: keyboard)
        #expect(abs((box.value.weightKg ?? 0) - UnitConversion.convertWeightToKg(225, from: ExerciseWeightUnit.pounds)) < 0.0001)
    }

    @Test func weightTakesOneDecimalPointAndTwoPlaces() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        type(".5.25", into: keyboard)
        #expect(keyboard.text == "0.52")
    }

    /// A comma region types and shows a comma, and the weight still lands. `Double("82,5")` is nil,
    /// so the old parse would have dropped a decimal weight typed with the region's separator.
    @Test func aCommaRegionTypesAndReadsItsOwnSeparator() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.locale = Locale(identifier: "es_ES")
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        #expect(keyboard.decimalSeparator == ",")

        type("82.5", into: keyboard)
        #expect(keyboard.text == "82,5")
        #expect(box.value.weightKg == 82.5)

        keyboard.close()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        #expect(keyboard.text == "82,5")
        #expect(WeightStepper.format(82.5, locale: Locale(identifier: "es_ES")) == "82,5")
    }

    @Test func repsTakeDigitsOnly() {
        let box = set()
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext())
        type("1.2x3", into: keyboard)
        #expect(box.value.reps == 123)
    }

    @Test func backspaceRightAfterOpeningClearsTheField() {
        let box = set(weightKg: 60)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        keyboard.backspace()
        #expect(box.value.weightKg == nil)
    }

    // MARK: - Next, Prev, Done

    @Test func nextAndPrevMoveBetweenTheFields() {
        let box = set(weightKg: 60, reps: 5)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())

        keyboard.next()
        #expect(keyboard.activeField == .reps)
        #expect(keyboard.text == "5")
        keyboard.type("8")
        #expect(box.value.reps == 8)

        keyboard.previous()
        #expect(keyboard.activeField == .weight)
        #expect(keyboard.text == "60")
    }

    @Test func repsOnlyHasNoWeightToGoBackTo() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext(fields: [.reps]))
        keyboard.previous()
        #expect(keyboard.activeField == .reps)
    }

    @Test func reopeningTheActiveFieldKeepsWhatWasTyped() {
        let box = set(weightKg: 60)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        type("7", into: keyboard)
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        type("0", into: keyboard)
        #expect(box.value.weightKg == 70)
    }

    @Test func doneOffersToLogAReadySet() {
        let box = set(weightKg: 60, reps: 8)
        let keyboard = SetKeyboardPresenter()
        var offers = 0
        keyboard.onOfferCompletion = { offers += 1 }
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext())
        keyboard.done()
        #expect(keyboard.activeField == nil)
        #expect(offers == 1)
    }

    // MARK: - Distance and duration

    @Test func distanceTakesADecimalInTheExercisesUnit() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.distance, set: box.binding, context: SetKeyboardContext(distanceUnit: .miles, fields: [.distance, .duration]))
        type("3.1", into: keyboard)
        #expect(abs((box.value.distanceMeters ?? 0) - UnitConversion.convertDistanceToMeters(3.1, from: .miles)) < 0.0001)
    }

    @Test func durationFillsFromTheRightLikeAMicrowave() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.duration, set: box.binding, context: SetKeyboardContext(fields: [.duration]))
        type("1", into: keyboard)
        #expect(box.value.durationSec == 1)
        #expect(keyboard.displayText(for: .duration, set: box.value, unit: .kilograms) == "0:01")
        type("30", into: keyboard)
        #expect(box.value.durationSec == 90)
        #expect(keyboard.displayText(for: .duration, set: box.value, unit: .kilograms) == "1:30")
        type(".", into: keyboard)
        #expect(keyboard.text == "130")
        keyboard.close()
        #expect(keyboard.displayText(for: .duration, set: box.value, unit: .kilograms) == "1:30")
    }

    @Test func reopeningADurationStartsFromItsDigits() {
        let box = set(weightKg: nil)
        box.value.durationSec = 125
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.duration, set: box.binding, context: SetKeyboardContext(fields: [.duration]))
        #expect(keyboard.text == "205")
    }

    @Test func nextWalksDistanceThenDuration() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.distance, set: box.binding, context: SetKeyboardContext(fields: [.distance, .duration]))
        #expect(keyboard.previousField == nil)
        keyboard.next()
        #expect(keyboard.activeField == .duration)
        #expect(keyboard.nextField == nil)
        keyboard.previous()
        #expect(keyboard.activeField == .distance)
    }

    /// Whether the set is ready is the row's call, since it depends on the tracking mode; the
    /// keyboard hands over on every Done.
    @Test func doneAlwaysHandsOverToTheRow() {
        let box = set(weightKg: 60, reps: nil)
        let keyboard = SetKeyboardPresenter()
        var offers = 0
        keyboard.onOfferCompletion = { offers += 1 }
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        keyboard.done()
        #expect(offers == 1)
    }

    @Test func closeOffersNothing() {
        let box = set(weightKg: 60, reps: 8)
        let keyboard = SetKeyboardPresenter()
        var offers = 0
        keyboard.onOfferCompletion = { offers += 1 }
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        keyboard.close()
        #expect(keyboard.activeField == nil)
        #expect(offers == 0)
    }

    // MARK: - Stepper, chips, plates

    @Test func stepperMovesByTheEquipmentStep() {
        let box = set(weightKg: 60)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        keyboard.stepUp()
        #expect(box.value.weightKg == 62.5)
        #expect(keyboard.text == "62.5")
        keyboard.stepDown()
        keyboard.stepDown()
        #expect(box.value.weightKg == 57.5)
    }

    @Test func bandsCycleNamesAndLeaveTheWeightEmpty() {
        let box = set(weightKg: 20)
        let keyboard = SetKeyboardPresenter()
        let bands = WeightStep(kind: .bands(["Light", "Heavy"]), chip: nil, baseWeight: nil, plates: [])
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext(step: bands))
        keyboard.stepUp()
        #expect(box.value.weightKg == nil)
        keyboard.close()
        #expect(keyboard.displayText(for: .weight, set: box.value, unit: .kilograms) == "Light")
        keyboard.stepDown()
        #expect(keyboard.displayText(for: .weight, set: box.value, unit: .kilograms) == "Heavy")
    }

    @Test func chipsShowInTheDisplayUnit() {
        let box = set()
        let keyboard = SetKeyboardPresenter()
        let context = SetKeyboardContext(
            unit: .pounds,
            lastSetWeightKg: UnitConversion.convertWeightToKg(135, from: ExerciseWeightUnit.pounds),
            lastSetReps: 8,
            targetWeightKg: UnitConversion.convertWeightToKg(145, from: ExerciseWeightUnit.pounds),
            targetMinReps: 6,
            targetMaxReps: 10
        )
        keyboard.open(.weight, set: box.binding, context: context)
        #expect(keyboard.weightChips.map(\.title) == ["Last set 135", "Target 145"])
        #expect(keyboard.repsChips.map(\.title) == ["Last set 8", "Min 6", "Max 10"])

        keyboard.applyWeight(displayValue: keyboard.weightChips[1].value)
        #expect(keyboard.text == "145")
    }

    @Test func platesForTheCurrentWeight() {
        let box = set(weightKg: 100)
        let keyboard = SetKeyboardPresenter()
        let bar = WeightStep(kind: .increment(2.5, min: 20, max: nil), chip: "Bar 20 kg", baseWeight: 20, plates: [1.25, 2.5, 5, 10, 15, 20, 25])
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext(step: bar))
        #expect(keyboard.plateLoad == .loadable(perSide: [25, 15]))
    }

    // MARK: - Effort

    @Test func rpeChipWritesTheSetAndTogglesOff() {
        let box = set()
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext(showsEffort: true))
        keyboard.toggleRPE(8.5)
        #expect(box.value.rpe == 8.5)
        #expect(keyboard.selectedRPE == 8.5)
        keyboard.toggleRPE(8.5)
        #expect(box.value.rpe == nil)
    }

    @Test func rpeAndRirAreOneScale() {
        #expect(EffortScale.rpeChoices == [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10])
        #expect(EffortScale.rir(fromRPE: 8) == 2)
        #expect(EffortScale.rir(fromRPE: 10) == 0)
        #expect(EffortScale.rpe(fromRIR: 3) == 7)
    }
}

/// The row's side of the keyboard: what it resolves before opening one, and what Done leads to.
@MainActor
struct SetTrackerRowKeyboardTests {

    private final class Interactor: SpyGlobalInteractor, SetTrackerRowInteractor {
        var workoutSettings = WorkoutSettings(authorId: "u")
        var allExercises: [ExerciseModel] = []
        var favouriteGymProfile: GymProfileModel?
        func getPreference(templateId: String) -> ExerciseUnitPreference { ExerciseUnitPreference(exerciseModelId: templateId) }
        func exerciseRestOverride(for exerciseId: String) -> Int? { nil }
    }

    private final class Router: SetTrackerRowRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alerts: [String] = []
        func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) { }
        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alerts.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alerts.append(title) }
        func showDevSettingsView() { }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private struct Row {
        let presenter: SetTrackerRowPresenter
        let interactor: Interactor
        let router: Router
        let delegate: SetTrackerRowDelegate
        let exercise: GymEquipmentBox<WorkoutExerciseModel>
    }

    private func makeRow() -> Row {
        let sets = (0..<2).map {
            WorkoutSetModel(id: "s\($0)", authorId: "u", index: $0, reps: $0 == 0 ? 10 : nil, weightKg: $0 == 0 ? 60 : nil, isWarmup: false, dateCreated: start)
        }
        let exercise = GymEquipmentBox(WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "t", name: "Squat", trackingMode: .weightReps, index: 0, sets: sets,
            setTargets: [SetTarget(setNumber: 2, minReps: 6, maxReps: 8)],
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: [EquipmentRef(kind: .loadableBar, id: "barbell")])]
        ))
        let setBinding = Binding(
            get: { exercise.value.sets[1] },
            set: { exercise.value.sets[1] = $0 }
        )
        let delegate = SetTrackerRowDelegate(exercise: exercise.binding, set: setBinding, lastSet: sets[0])
        let interactor = Interactor()
        let router = Router()
        return Row(
            presenter: SetTrackerRowPresenter(interactor: interactor, router: router),
            interactor: interactor, router: router, delegate: delegate, exercise: exercise
        )
    }

    @Test func contextComesFromTheGymTheSettingsAndTheSetBefore() {
        let row = makeRow()
        let (presenter, interactor, delegate) = (row.presenter, row.interactor, row.delegate)
        interactor.favouriteGymProfile = GymProfileModel(authorId: "u")
        interactor.workoutSettings.rirTracking = true

        let context = presenter.keyboardContext(delegate: delegate)
        #expect(context.step.isPlateLoaded)
        #expect(context.step.chip?.hasPrefix("Bar ") == true)
        #expect(context.showsEffort)
        #expect(context.lastSetWeightKg == 60)
        #expect(context.lastSetReps == 10)
        #expect(context.targetMinReps == 6)
        #expect(context.targetMaxReps == 8)
    }

    @Test func withoutAGymTheStepIsTheDefault() {
        let row = makeRow()
        let (presenter, delegate) = (row.presenter, row.delegate)
        #expect(presenter.keyboardContext(delegate: delegate).step == WeightStepper.fallback(.kilograms))
    }

    /// Done logs a ready set outright; it used to raise a "Complete Set?" alert first.
    @Test func doneOnAReadySetLogsIt() {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        "80".forEach { presenter.keyboard.type($0) }
        presenter.keyboard.next()
        "5".forEach { presenter.keyboard.type($0) }
        #expect(exercise.value.sets[1].weightKg == 80)
        #expect(exercise.value.sets[1].reps == 5)

        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect(exercise.value.sets[1].completedAt != nil)
    }

    @Test(arguments: [(nil as Int?, false), (0, false), (8, true)])
    func doneOffersNothingWithoutRepsOrOnceLogged(reps: Int?, completed: Bool) {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        exercise.value.sets[1].reps = reps
        exercise.value.sets[1].completedAt = completed ? start : nil
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect((exercise.value.sets[1].completedAt != nil) == completed)
    }

    /// Logged by Done, rather than offered as it was before, once it has a time.
    @Test func aTimedSetIsLoggedOnceItHasATime() {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        exercise.value.trackingMode = .timeOnly
        #expect(presenter.keyboardContext(delegate: delegate).fields == [.duration])
        presenter.onKeyboardFieldBegan(.duration, delegate: delegate)
        "45".forEach { presenter.keyboard.type($0) }
        presenter.keyboard.done()
        #expect(exercise.value.sets[1].durationSec == 45)
        #expect(router.alerts.isEmpty)
        #expect(exercise.value.sets[1].completedAt != nil)
    }

    @Test func doneOnAnUnfinishedSetJustCloses() {
        let row = makeRow()
        let (presenter, router, delegate) = (row.presenter, row.router, row.delegate)
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect(presenter.keyboard.activeField == nil)
    }
}
