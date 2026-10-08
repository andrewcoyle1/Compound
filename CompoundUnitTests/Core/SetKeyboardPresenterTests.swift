//
//  SetKeyboardPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The weight and reps keyboards: every key writes into the set as it is pressed, Next and Prev
/// move between the two fields, and Done only closes.
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

    /// Done only closes, even on a set that is ready: the log button is the one way to log.
    @Test func doneClosesAndLetsGoOfTheSet() {
        let box = set(weightKg: 60, reps: 8)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext())
        keyboard.done()
        #expect(keyboard.activeField == nil)
        #expect(box.value.completedAt == nil)
        keyboard.applyReps(12)
        #expect(box.value.reps == 8)
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

    // MARK: - VoiceOver

    /// What is read back after a key: the value with its unit in words, never the key alone.
    @Test func theNewValueIsSpokenInWords() {
        let box = set(weightKg: 100, reps: 6)
        let keyboard = SetKeyboardPresenter()
        keyboard.locale = Locale(identifier: "en_US")
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        type("102.5", into: keyboard)
        #expect(keyboard.spokenValue == "102.5 kilograms")
        #expect(keyboard.spokenWeight == "102.5 kilograms")
        keyboard.next()
        #expect(keyboard.spokenValue == "6 reps")
        keyboard.backspace()
        #expect(keyboard.spokenValue == nil)
    }

    @Test func aDurationIsSpokenInMinutesAndSeconds() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.locale = Locale(identifier: "en_US")
        keyboard.open(.duration, set: box.binding, context: SetKeyboardContext(fields: [.duration]))
        type("130", into: keyboard)
        #expect(keyboard.spokenValue == "1 minute, 30 seconds")
    }

    /// The set binding reads its set by index, so a keyboard that kept it after an earlier set was
    /// deleted would read past the end of the array (perf audit #8). Closing lets go of it.
    @Test func closeLetsGoOfTheSet() {
        let box = set(weightKg: 60, reps: 8)
        box.value.rpe = 8
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        #expect(keyboard.selectedRPE == 8)

        keyboard.close()
        keyboard.stepUp()
        keyboard.toggleRPE(9)

        #expect(keyboard.selectedRPE == nil)
        #expect(box.value.weightKg == 60)
        #expect(box.value.rpe == 8)
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
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext(step: bands))
        keyboard.stepDown()
        keyboard.close()
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

    /// Effort is recorded after the set, in the correction row; the keypad offers its RPE chips
    /// only to correct a set already logged.
    @Test(arguments: [(false, false, false), (true, false, false), (true, true, true)])
    func rpeChipsOnlyOnALoggedSet(showsEffort: Bool, logged: Bool, shown: Bool) {
        let box = set(reps: 8, done: logged)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.reps, set: box.binding, context: SetKeyboardContext(showsEffort: showsEffort))
        #expect(keyboard.showsEffortChips == shown)
    }

    @Test func rpeAndRirAreOneScale() {
        #expect(EffortScale.rpeChoices == [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10])
        #expect(EffortScale.rir(fromRPE: 8) == 2)
        #expect(EffortScale.rir(fromRPE: 10) == 0)
        #expect(EffortScale.rpe(fromRIR: 3) == 7)
    }

    // MARK: - WP-N: assistance and placeholders

    private func assistedContext(bodyweightOnly: Bool = true) -> SetKeyboardContext {
        SetKeyboardContext(step: WeightStepper.fallback(.kilograms).assisted(bodyweightOnly: bodyweightOnly))
    }

    /// The ± key shows only on an assisted exercise's weight field.
    @Test func theSignKeyShowsOnlyForAnAssistedWeight() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        #expect(!keyboard.showsSignKey)
        keyboard.close()
        keyboard.open(.weight, set: box.binding, context: assistedContext())
        #expect(keyboard.showsSignKey)
        keyboard.open(.reps, set: box.binding, context: assistedContext())
        #expect(!keyboard.showsSignKey)
    }

    /// "± 3 0" types −30, ± flips a stored weight, and typing over a negative keeps it negative.
    @Test func signKeyTypesAndFlipsAssistance() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: assistedContext())
        keyboard.toggleSign()
        #expect(keyboard.text == "-")
        #expect(box.value.weightKg == nil)
        type("30", into: keyboard)
        #expect(box.value.weightKg == -30)

        keyboard.toggleSign()
        #expect(box.value.weightKg == 30)
        keyboard.toggleSign()
        #expect(box.value.weightKg == -30)
        #expect(keyboard.text == "-30")

        // The first key after a flip replaces the value, but assistance stays assistance.
        type("25", into: keyboard)
        #expect(box.value.weightKg == -25)
    }

    /// A hardware keyboard's minus key is the ± key, and does nothing on an ordinary weight.
    @Test func aHardwareMinusFlipsOnlyAnAssistedWeight() {
        let box = set(weightKg: 20)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext())
        keyboard.type("-")
        #expect(box.value.weightKg == 20)
        keyboard.close()
        keyboard.open(.weight, set: box.binding, context: assistedContext(bodyweightOnly: false))
        keyboard.type("-")
        #expect(box.value.weightKg == -20)
    }

    /// − on an empty assisted field gives one step of assistance, not the deepest there is.
    @Test func steppingDownAnEmptyAssistedFieldGivesOneStepOfHelp() {
        let box = set(weightKg: nil)
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: assistedContext())
        keyboard.stepDown()
        #expect(box.value.weightKg == -2.5)
        keyboard.stepUp()
        keyboard.stepUp()
        #expect(box.value.weightKg == 0)
    }

    /// An empty field's hint is last time's value, greyed; it is never written into the set.
    @Test func placeholdersShowLastTimeAndAreNeverValues() {
        let keyboard = SetKeyboardPresenter()
        keyboard.locale = Locale(identifier: "en_US")
        let previous = WorkoutSetModel(
            id: "p", authorId: "u", index: 0, reps: 8, weightKg: -30, durationSec: 45,
            isWarmup: false, completedAt: start, dateCreated: start
        )
        #expect(keyboard.placeholder(for: .duration, previous: previous, unit: .kilograms) == "0:45")
        #expect(keyboard.placeholder(for: .weight, previous: previous, unit: .kilograms) == "-30")
        #expect(keyboard.placeholder(for: .reps, previous: previous, unit: .kilograms) == "8")
        #expect(keyboard.placeholder(for: .distance, previous: previous, unit: .kilograms) == Format.placeholder)
        #expect(keyboard.placeholder(for: .duration, previous: nil, unit: .kilograms) == Format.placeholder)

        let empty = set(weightKg: nil)
        #expect(keyboard.displayText(for: .weight, set: empty.value, unit: .kilograms).isEmpty)
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

    /// Done never logs, however ready the set: decision T1 reverses 5d, which logged it here and
    /// turned weight changes made before a set into logged sets.
    @Test func doneNeverLogsAReadySet() {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        var logged: [String] = []
        presenter.onLogSet = { setId, _ in logged.append(setId) }
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        "80".forEach { presenter.keyboard.type($0) }
        presenter.keyboard.next()
        "5".forEach { presenter.keyboard.type($0) }
        #expect(exercise.value.sets[1].weightKg == 80)
        #expect(exercise.value.sets[1].reps == 5)

        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect(logged.isEmpty)
        #expect(exercise.value.sets[1].completedAt == nil)
        #expect(presenter.keyboard.activeField == nil)
    }

    @Test(arguments: [(nil as Int?, false), (0, false), (8, true)])
    func doneLeavesALoggedSetLogged(reps: Int?, completed: Bool) {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        exercise.value.sets[1].reps = reps
        exercise.value.sets[1].completedAt = completed ? start : nil
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect(exercise.value.sets[1].completedAt == (completed ? start : nil))
    }

    @Test func aTimedSetIsNotLoggedByDone() {
        let row = makeRow()
        let (presenter, router, delegate, exercise) = (row.presenter, row.router, row.delegate, row.exercise)
        exercise.value.trackingMode = .timeOnly
        #expect(presenter.keyboardContext(delegate: delegate).fields == [.duration])
        presenter.onKeyboardFieldBegan(.duration, delegate: delegate)
        "45".forEach { presenter.keyboard.type($0) }
        presenter.keyboard.done()
        #expect(exercise.value.sets[1].durationSec == 45)
        #expect(router.alerts.isEmpty)
        #expect(exercise.value.sets[1].completedAt == nil)
    }

    @Test func doneOnAnUnfinishedSetJustCloses() {
        let row = makeRow()
        let (presenter, router, delegate) = (row.presenter, row.router, row.delegate)
        presenter.onKeyboardFieldBegan(.weight, delegate: delegate)
        presenter.keyboard.done()
        #expect(router.alerts.isEmpty)
        #expect(presenter.keyboard.activeField == nil)
    }

    /// The line under the set being logged: what goes on each side of the bar, or the nearest
    /// total the plates make when the weight cannot be loaded.
    @Test func plateSummaryReadsTheGymsPlates() throws {
        let row = makeRow()
        row.interactor.favouriteGymProfile = GymProfileModel(authorId: "u")
        var set = row.exercise.value.sets[0]
        // Read the gym's own bar and heaviest plate, so the figures hold whatever its defaults are.
        let step = WeightStepper.steps(for: row.exercise.value, profile: row.interactor.favouriteGymProfile, unit: .kilograms)
        let bar = try #require(step.baseWeight)
        let plate = try #require(step.plates.max())
        let loadableKg = bar + 2 * plate

        set.weightKg = loadableKg
        let loadable = row.presenter.plateSummary(exercise: row.exercise.value, set: set)
        #expect(loadable?.nearestKg == nil)
        #expect(loadable?.text.hasPrefix("Per side:") == true)

        // A hair over: nothing in the rack makes it, and the nearest total is the one below.
        set.weightKg = loadableKg + 0.1
        let unloadable = row.presenter.plateSummary(exercise: row.exercise.value, set: set)
        #expect(unloadable?.nearestKg == loadableKg)

        set.weightKg = nil
        #expect(row.presenter.plateSummary(exercise: row.exercise.value, set: set) == nil)
    }

    // MARK: - WP-N: assistance

    /// The row opens an assisted exercise's keypad on the assisted step.
    @Test func anAssistedExerciseOpensOnTheAssistedStep() {
        let row = makeRow()
        row.interactor.allExercises = [ExerciseModel(
            id: "t", authorId: "u", name: "Assisted Pull-Up", trackableMetrics: [.reps, .weightPerSideAssistance],
            type: .compoundUpper, laterality: .bilateral, muscleGroups: [.lats: .primary], isBodyweight: true,
            equipmentVariations: [], rangeOfMotion: 4, stability: 4, bodyWeightContribution: 100, alternateNames: []
        )]
        let context = row.presenter.keyboardContext(delegate: row.delegate)
        #expect(context.step.isAssisted)
        #expect(context.step.next(after: 0) == 0)
        #expect(row.presenter.isAssisted(row.exercise.value))
    }
}
