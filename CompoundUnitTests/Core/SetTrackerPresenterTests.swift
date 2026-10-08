//
//  SetTrackerPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The set-by-set screen inside a live workout: adding and deleting sets, deciding when one can be
/// marked done, switching units, and showing what was lifted last time.
///
/// Everything here writes straight into the session being logged, through a `Binding`, so a
/// mistake lands in the user's training history rather than on screen. The set indices are the
/// load-bearing part — they are what last session's figures are matched against.
@MainActor
struct SetTrackerPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, SetTrackerInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var systemExercises: [ExerciseModel] = []
        var userExercises: [ExerciseModel] = []
        var allExercises: [ExerciseModel] = []
        var favouriteGymProfile: GymProfileModel?
        var workoutGymProfile: GymProfileModel?
        var workoutSettings: WorkoutSettings = WorkoutSettings(authorId: "user-1")

        var preferences: [String: ExerciseUnitPreference] = [:]
        private(set) var savedWeightUnits: [(String, ExerciseWeightUnit)] = []
        private(set) var savedDistanceUnits: [(String, ExerciseDistanceUnit)] = []

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }

        /// Stores the unit as the manager does, as well as recording the call.
        func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
            savedWeightUnits.append((templateId, unit))
            preferences[templateId, default: ExerciseUnitPreference(exerciseModelId: templateId)].weightUnit = unit
        }

        func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
            savedDistanceUnits.append((templateId, unit))
            preferences[templateId, default: ExerciseUnitPreference(exerciseModelId: templateId)].distanceUnit = unit
        }
    }

    /// The alerts this screen raises — delete, superset, unit change — all go through
    /// `showAlert(title:subtitle:buttons:)` and `showSimpleAlert`, which are `GlobalRouter`
    /// extensions rather than requirements of `SetTrackerRouter`. They dispatch statically and
    /// never reach this double, so the tests assert the state that is reachable instead.
    private final class Router: SetTrackerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        var swapSelection: ExerciseModel?

        func showWorkoutExerciseEquipmentSheetView(delegate: WorkoutExerciseEquipmentSheetDelegate) {
            shown.append("equipment")
        }

        func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) {
            shown.append("warmupInfo")
        }

        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) {
            shown.append("rest")
        }

        func showWarmupSetsView(delegate: WarmupSetsDelegate) {
            shown.append("warmupSets")
        }

        func showExerciseSettingsView(delegate: ExerciseSettingsDelegate) {
            shown.append("exerciseSettings")
        }

        func showSetTargetView(delegate: SetTargetDelegate) {
            shown.append("setTarget")
        }

        /// Hands back `swapSelection` when one is set, standing in for the user picking.
        func showSwapExercisePickerView(alternativeIds: [String], onSelect: @escaping (ExerciseModel) -> Void) {
            shown.append("swapPicker")
            if let swapSelection {
                onSelect(swapSelection)
            }
        }

        /// A requirement of `GlobalRouter`, so unlike the alerts it does reach this double.
        private(set) var confirmations: [String] = []
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            confirmations.append(title)
        }
    }

    /// Holds the exercise being edited, so the presenter's `Binding`-taking methods can be driven
    /// without a view and the result read back.
    ///
    /// Main-actor isolated so it is `Sendable`, which `Binding`'s `@Sendable` accessors require.
    @MainActor
    private final class MutableExercise {
        var value: WorkoutExerciseModel

        init(_ value: WorkoutExerciseModel) {
            self.value = value
        }

        var binding: Binding<WorkoutExerciseModel> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    private struct Screen {
        let presenter: SetTrackerPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: SetTrackerPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func set(
        id: String,
        index: Int,
        reps: Int? = 10,
        weightKg: Double? = 100,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil,
        isWarmup: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "user-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            durationSec: durationSec,
            distanceMeters: distanceMeters,
            isWarmup: isWarmup,
            dateCreated: Date()
        )
    }

    private func exercise(
        templateId: String = "template-1",
        mode: TrackingMode = .weightReps,
        sets: [WorkoutSetModel]
    ) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "user-1",
            templateId: templateId,
            name: "Bench Press",
            trackingMode: mode,
            index: 1,
            sets: sets
        )
    }

    // MARK: - Adding and deleting sets

    @Test("Test Adding A Set Appends It After The Last")
    func testAddingASetAppendsItAfterTheLast() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1), set(id: "s2", index: 2)]))

        screen.presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.map(\.index) == [1, 2, 3])
    }

    /// A new set carries the last one's figures and bands forward, since the next set of an
    /// exercise is usually the same weight and reps as the one before it.
    @Test("Test A New Set Carries The Last Ones Figures Forward")
    func testANewSetCarriesTheLastOnesFiguresForward() {
        let screen = makeScreen()
        var last = set(id: "s1", index: 1, reps: 8, weightKg: 80)
        last.bands = ["Red"]
        let box = MutableExercise(exercise(sets: [last]))
        screen.presenter.addSet(exercise: box.binding)
        #expect(box.value.sets.last?.reps == 8)
        #expect(box.value.sets.last?.weightKg == 80)
        #expect(box.value.sets.last?.bands == ["Red"])
    }

    /// A new set is never already complete, whatever the set it copied from was.
    @Test("Test A New Set Is Not Already Complete")
    func testANewSetIsNotAlreadyComplete() {
        let screen = makeScreen()
        var done = set(id: "s1", index: 1)
        done.completedAt = Date()
        let box = MutableExercise(exercise(sets: [done]))

        screen.presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.last?.completedAt == nil)
        #expect(box.value.sets.last?.isWarmup == false)
    }

    @Test("Test Deleting A Set Removes Only That One")
    func testDeletingASetRemovesOnlyThatOne() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [
            set(id: "s1", index: 1), set(id: "s2", index: 2), set(id: "s3", index: 3)
        ]))

        screen.presenter.deleteSet(setId: "s2", exercise: box.binding)

        #expect(box.value.sets.map(\.id) == ["s1", "s3"])
    }

    /// The one that used to break. Deleting a set does not renumber the rest, so the count stops
    /// reaching the highest index — and the new set was handed an index another set already held.
    /// Duplicate indices are what last session's figures are matched on, and they crashed the
    /// lookup the next time the exercise was tracked.
    @Test("Test Adding After A Delete Does Not Reuse An Index")
    func testAddingAfterADeleteDoesNotReuseAnIndex() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [
            set(id: "s1", index: 1), set(id: "s2", index: 2), set(id: "s3", index: 3)
        ]))

        screen.presenter.deleteSet(setId: "s2", exercise: box.binding)
        screen.presenter.addSet(exercise: box.binding)

        let indices = box.value.sets.map(\.index)
        #expect(indices == [1, 3, 4])
        #expect(Set(indices).count == indices.count)
    }

    /// Warmup sets share the same numbering as working sets, so they raise the highest index and
    /// the next set has to clear them too.
    @Test("Test Warmup Sets Count Towards The Next Index")
    func testWarmupSetsCountTowardsTheNextIndex() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [
            set(id: "w1", index: 1, isWarmup: true),
            set(id: "w2", index: 2, isWarmup: true),
            set(id: "s1", index: 3)
        ]))

        screen.presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.map(\.index) == [1, 2, 3, 4])
    }

    @Test("Test Adding To An Empty Exercise Starts At One")
    func testAddingToAnEmptyExerciseStartsAtOne() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: []))

        screen.presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.map(\.index) == [1])
    }

    /// Without a signed-in user there is nobody to author the set, so none is added.
    @Test("Test No Set Is Added Without A User")
    func testNoSetIsAddedWithoutAUser() {
        let screen = makeScreen()
        screen.interactor.userId = nil
        let box = MutableExercise(exercise(sets: []))

        screen.presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.isEmpty)
    }

    // MARK: - Last session's figures

    /// What the user last did for `templateId`, in the shape the presenter now holds it: keyed by
    /// the exercise's template id rather than wrapped in a whole session.
    private func previousExercises(
        sets: [WorkoutSetModel],
        templateId: String = "template-1"
    ) -> [String: WorkoutExerciseModel] {
        [
            templateId: WorkoutExerciseModel(
                id: "prev-exercise",
                authorId: "user-1",
                templateId: templateId,
                name: "Bench Press",
                trackingMode: .weightReps,
                index: 1,
                sets: sets
            )
        ]
    }

    @Test("Test Last Sessions Sets Are Matched By Index And Side")
    func testLastSessionsSetsAreMatchedByIndexAndSide() {
        let screen = makeScreen()
        screen.presenter.previousExercises = previousExercises(sets: [
            set(id: "p1", index: 1, reps: 8, weightKg: 80),
            set(id: "p2", index: 2, reps: 6, weightKg: 90)
        ])

        let lookup = screen.presenter.buildPreviousLookup(for: exercise(sets: []))

        #expect(lookup[PreviousSetKey(index: 1, side: nil)]?.weightKg == 80)
        #expect(lookup[PreviousSetKey(index: 2, side: nil)]?.weightKg == 90)
    }

    /// Sessions saved before the index reuse was fixed are still in people's histories, holding
    /// two sets numbered the same. Building this lookup used to trap on that, taking the screen
    /// down every time the exercise was opened.
    @Test("Test Duplicate Indices From Old Sessions Do Not Crash")
    func testDuplicateIndicesFromOldSessionsDoNotCrash() {
        let screen = makeScreen()
        screen.presenter.previousExercises = previousExercises(sets: [
            set(id: "p1", index: 1, reps: 8, weightKg: 80),
            set(id: "p2", index: 3, reps: 6, weightKg: 90),
            set(id: "p3", index: 3, reps: 5, weightKg: 95)
        ])

        let lookup = screen.presenter.buildPreviousLookup(for: exercise(sets: []))

        #expect(lookup.count == 2)
        #expect(lookup[PreviousSetKey(index: 1, side: nil)]?.weightKg == 80)
        // The later set wins, which is the one further down the screen last time.
        #expect(lookup[PreviousSetKey(index: 3, side: nil)]?.weightKg == 95)
    }

    @Test("Test A Different Exercise Has No Previous Sets")
    func testADifferentExerciseHasNoPreviousSets() {
        let screen = makeScreen()
        screen.presenter.previousExercises = previousExercises(sets: [set(id: "p1", index: 1)])

        let lookup = screen.presenter.buildPreviousLookup(for: exercise(templateId: "other", sets: []))

        #expect(lookup.isEmpty)
    }

    @Test("Test No Previous Exercise Means No Previous Sets")
    func testNoPreviousSessionMeansNoPreviousSets() {
        let screen = makeScreen()

        #expect(screen.presenter.buildPreviousLookup(for: exercise(sets: [])).isEmpty)
    }

    // MARK: - Units

    /// The presenter reads the preference manager rather than a copy of its own. A copy went stale
    /// when the unit changed elsewhere, and the keypad converted typed pounds from kilograms.
    @Test("Test A Unit Changed Elsewhere Is Read Straight Away")
    func testAUnitChangedElsewhereIsReadStraightAway() {
        let screen = makeScreen()
        screen.interactor.preferences["template-1"] = ExerciseUnitPreference(
            exerciseModelId: "template-1",
            weightUnit: .pounds
        )
        let model = exercise(sets: [])

        let first = screen.presenter.getUnitPreference(for: model)
        screen.interactor.preferences["template-1"] = ExerciseUnitPreference(
            exerciseModelId: "template-1",
            weightUnit: .kilograms
        )
        let second = screen.presenter.getUnitPreference(for: model)

        #expect(first.weightUnit == .pounds)
        #expect(second.weightUnit == .kilograms)
    }

    /// Changing the display unit is per exercise and persisted, so it survives leaving the screen.
    @Test("Test Changing The Weight Unit Is Saved For That Exercise")
    func testChangingTheWeightUnitIsSavedForThatExercise() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1)]))

        screen.presenter.updateWeightUnit(.pounds, for: box.binding)

        #expect(screen.interactor.savedWeightUnits.first?.0 == "template-1")
        #expect(screen.interactor.savedWeightUnits.first?.1 == .pounds)
        #expect(screen.presenter.getUnitPreference(for: box.value).weightUnit == .pounds)
    }

    /// Display-only leaves what was lifted alone. The weight is stored in kilograms whatever is
    /// shown, so changing the unit must not rewrite the history.
    @Test("Test Changing The Display Unit Leaves The Weights Alone")
    func testChangingTheDisplayUnitLeavesTheWeightsAlone() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1, weightKg: 100)]))

        screen.presenter.updateWeightUnit(.pounds, for: box.binding)

        #expect(box.value.sets.first?.weightKg == 100)
    }

    /// Converting rounds to something loadable in the new unit — 100kg is 220.46lb, which nobody
    /// puts on a bar, so it becomes a whole number of pounds.
    @Test("Test Converting Weights Rounds Them In The New Unit")
    func testConvertingWeightsRoundsThemInTheNewUnit() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1, weightKg: 100)]))

        screen.presenter.convertAndRoundWeights(to: .pounds, for: box.binding)

        let stored = box.value.sets.first?.weightKg ?? 0
        let inPounds = UnitConversion.convertWeight(stored, to: ExerciseWeightUnit.pounds)
        #expect(abs(inPounds - inPounds.rounded()) < 0.001)
        #expect(screen.interactor.savedWeightUnits.last?.1 == .pounds)
    }

    /// A set with no weight has nothing to convert, and must not gain one.
    @Test("Test Converting Leaves A Weightless Set Weightless")
    func testConvertingLeavesAWeightlessSetWeightless() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1, weightKg: nil)]))

        screen.presenter.convertAndRoundWeights(to: .pounds, for: box.binding)

        #expect(box.value.sets.first?.weightKg == nil)
    }

    @Test("Test Converting Distances Rounds Them In The New Unit")
    func testConvertingDistancesRoundsThemInTheNewUnit() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(
            mode: .distanceTime,
            sets: [set(id: "s1", index: 1, reps: nil, weightKg: nil, distanceMeters: 5432)]
        ))

        screen.presenter.convertAndRoundDistances(to: .miles, for: box.binding)

        let stored = box.value.sets.first?.distanceMeters ?? 0
        let inMiles = UnitConversion.convertDistance(stored, to: ExerciseDistanceUnit.miles)
        // Miles keep two decimals, so the stored metres round-trip to a clean figure.
        #expect(abs(inMiles - (inMiles * 100).rounded() / 100) < 0.0001)
        #expect(screen.interactor.savedDistanceUnits.last?.1 == .miles)
    }

    /// Choosing the unit already in use is not a change, so the user is not asked how to apply it.
    @Test("Test Choosing The Current Unit Prompts Nothing")
    func testChoosingTheCurrentUnitPromptsNothing() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1, weightKg: 100)]))

        screen.presenter.promptWeightUnitChange(.kilograms, for: box.binding)

        #expect(screen.interactor.savedWeightUnits.isEmpty)
        #expect(box.value.sets.first?.weightKg == 100)
    }

    // MARK: - Swapping an exercise

    /// Swapping replaces the exercise wholesale and starts its sets fresh. Keeping the old sets
    /// would log the previous exercise's weights against the new movement.
    @Test("Test Swapping An Exercise Starts Its Sets Fresh")
    func testSwappingAnExerciseStartsItsSetsFresh() {
        let screen = makeScreen()
        let replacement = ExerciseModel.mock
        screen.router.swapSelection = replacement
        let box = MutableExercise(exercise(sets: [
            set(id: "s1", index: 1, reps: 8, weightKg: 100),
            set(id: "s2", index: 2, reps: 8, weightKg: 100)
        ]))

        screen.presenter.onSwapPressed(box.binding)

        #expect(box.value.templateId == replacement.id)
        #expect(box.value.name == replacement.name)
        #expect(box.value.sets.allSatisfy { $0.weightKg == nil })
        #expect(box.value.chosenVariationId == nil)
    }

    /// A swap mid-exercise keeps what was done: the logged sets move to the replacement, which is
    /// measured the same way, and only the open ones start fresh, as many as there were.
    @Test("Test Swapping To An Exercise Measured The Same Way Keeps The Logged Sets")
    func testSwappingToAnExerciseMeasuredTheSameWayKeepsTheLoggedSets() throws {
        let screen = makeScreen()
        let replacement = try #require(ExerciseModel.mocks.first { !WorkoutSessionModel.isPerSide($0) })
        screen.router.swapSelection = replacement
        var logged = set(id: "s1", index: 1, reps: 8, weightKg: 100)
        logged.completedAt = Date()
        let box = MutableExercise(exercise(
            mode: WorkoutSessionModel.trackingMode(for: replacement),
            sets: [logged, set(id: "s2", index: 2), set(id: "s3", index: 3)]
        ))

        screen.presenter.onSwapPressed(box.binding)

        #expect(screen.router.confirmations.isEmpty)
        #expect(box.value.templateId == replacement.id)
        #expect(box.value.sets.count == 3)
        #expect(box.value.sets.first?.id == "s1")
        #expect(box.value.sets.first?.completedAt != nil)
        let fresh = box.value.sets.dropFirst()
        #expect(fresh.allSatisfy { $0.completedAt == nil && $0.weightKg == nil })
        let indices = box.value.sets.map { $0.index }
        #expect(indices == [1, 2, 3])
    }

    /// Measured differently, the logged sets cannot move, so the person is asked before they go;
    /// nothing changes until they answer, and "Swap and Discard Sets" starts the exercise fresh.
    @Test("Test Swapping To An Exercise Measured Differently Asks Before Discarding")
    func testSwappingToAnExerciseMeasuredDifferentlyAsksBeforeDiscarding() throws {
        let screen = makeScreen()
        let replacement = try #require(ExerciseModel.mocks.first { !WorkoutSessionModel.isPerSide($0) })
        screen.router.swapSelection = replacement
        let otherMode: TrackingMode = WorkoutSessionModel.trackingMode(for: replacement) == .timeOnly ? .weightReps : .timeOnly
        var logged = set(id: "s1", index: 1)
        logged.completedAt = Date()
        let box = MutableExercise(exercise(mode: otherMode, sets: [logged, set(id: "s2", index: 2)]))

        screen.presenter.onSwapPressed(box.binding)

        #expect(screen.router.confirmations == ["Discard Logged Sets?"])
        #expect(box.value.templateId == "template-1")
        #expect(box.value.sets.first?.completedAt != nil)

        screen.presenter.swap(box.binding, to: replacement, keepingLoggedSets: false)

        #expect(box.value.templateId == replacement.id)
        #expect(box.value.sets.count == 3)
        #expect(box.value.sets.allSatisfy { $0.completedAt == nil })
    }

    /// The equipment choice belonged to the old exercise, so it goes with it.
    @Test("Test Swapping Clears The Old Equipment Choice")
    func testSwappingClearsTheOldEquipmentChoice() {
        let screen = makeScreen()
        screen.router.swapSelection = ExerciseModel.mock
        var model = exercise(sets: [set(id: "s1", index: 1)])
        model.chosenVariationId = "variation-1"
        let box = MutableExercise(model)

        screen.presenter.onSwapPressed(box.binding)

        #expect(box.value.chosenVariationId == nil)
    }

    // MARK: - Supersets

    /// Leaving a pair dissolves it: one exercise on its own is not a superset, so the partner is
    /// released rather than left in a group of one.
    @Test("Test Leaving A Pair Dissolves The Group")
    func testLeavingAPairDissolvesTheGroup() {
        let screen = makeScreen()
        var mine = exercise(sets: [])
        mine.supersetGroupId = "group-1"
        var partner = exercise(sets: [])
        partner = WorkoutExerciseModel(
            id: "exercise-2",
            authorId: "user-1",
            templateId: "template-2",
            name: "Row",
            trackingMode: .weightReps,
            index: 2,
            sets: [],
            supersetGroupId: "group-1"
        )
        let box = MutableExercise(mine)
        var released: [(String, String?)] = []

        screen.presenter.onSupersetPressed(
            exercise: box.binding,
            allWorkoutExercises: [mine, partner],
            onSetSupersetGroup: { id, group in released.append((id, group)) }
        )

        #expect(box.value.supersetGroupId == nil)
        #expect(released.count == 1)
        #expect(released.first?.0 == "exercise-2")
        #expect(released.first?.1 == nil)
    }

    /// Leaving a group of three leaves a pair behind, which is still a superset, so nobody is
    /// released.
    @Test("Test Leaving A Group Of Three Leaves The Others Grouped")
    func testLeavingAGroupOfThreeLeavesTheOthersGrouped() {
        let screen = makeScreen()
        var mine = exercise(sets: [])
        mine.supersetGroupId = "group-1"
        let others = (2...3).map { index in
            WorkoutExerciseModel(
                id: "exercise-\(index)",
                authorId: "user-1",
                templateId: "template-\(index)",
                name: "Other \(index)",
                trackingMode: .weightReps,
                index: index,
                sets: [],
                supersetGroupId: "group-1"
            )
        }
        let box = MutableExercise(mine)
        var released: [(String, String?)] = []

        screen.presenter.onSupersetPressed(
            exercise: box.binding,
            allWorkoutExercises: [mine] + others,
            onSetSupersetGroup: { id, group in released.append((id, group)) }
        )

        #expect(box.value.supersetGroupId == nil)
        #expect(released.isEmpty)
    }

    /// With nothing to pair with, the screen says so rather than opening an empty chooser.
    @Test("Test Pairing With Nothing Available Changes Nothing")
    func testPairingWithNothingAvailableChangesNothing() {
        let screen = makeScreen()
        let mine = exercise(sets: [])
        let box = MutableExercise(mine)
        var released: [(String, String?)] = []

        screen.presenter.onSupersetPressed(
            exercise: box.binding,
            allWorkoutExercises: [mine],
            onSetSupersetGroup: { id, group in released.append((id, group)) }
        )

        #expect(box.value.supersetGroupId == nil)
        #expect(released.isEmpty)
    }

    // MARK: - Navigation

    @Test("Test Exercise Settings Only Opens For A Known Exercise")
    func testExerciseSettingsOnlyOpensForAKnownExercise() {
        let screen = makeScreen()

        screen.presenter.onExerciseSettingsPressed(exercise: exercise(templateId: "missing", sets: []))

        #expect(screen.router.shown.isEmpty)
    }

    @Test("Test The Warmup Sets Screen Opens")
    func testTheWarmupSetsScreenOpens() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: []))

        screen.presenter.onWarmupSetsPressed(box.binding)

        #expect(screen.router.shown == ["warmupSets"])
    }

    @Test("Test The Equipment Sheet Opens")
    func testTheEquipmentSheetOpens() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(sets: []))

        screen.presenter.onExerciseEquipmentPressed(box.binding)

        #expect(screen.router.shown == ["equipment"])
    }

    @Test("Test Targets Only Open For A Known Exercise")
    func testTargetsOnlyOpenForAKnownExercise() {
        let screen = makeScreen()
        let box = MutableExercise(exercise(templateId: "missing", sets: []))

        screen.presenter.onTargetsPressed(box.binding)

        #expect(screen.router.shown.isEmpty)
    }
}

/// Kept apart from the struct, which is at the type-body limit; same file, so the doubles are shared.
extension SetTrackerPresenterTests {

    /// A logged set is history: 100 kg converted to 220 lb would record 99.79 kg. Only open sets change.
    @Test("Test Converting Leaves Logged Sets Untouched")
    func testConvertingLeavesLoggedSetsUntouched() {
        let screen = makeScreen()
        var logged = set(id: "s1", index: 1, weightKg: 100, distanceMeters: 5432)
        logged.completedAt = Date()
        let box = MutableExercise(exercise(sets: [logged, set(id: "s2", index: 2, weightKg: 100, distanceMeters: 5432)]))

        screen.presenter.convertAndRoundWeights(to: .pounds, for: box.binding)
        screen.presenter.convertAndRoundDistances(to: .miles, for: box.binding)

        #expect(box.value.sets[0].weightKg == 100)
        #expect(box.value.sets[0].distanceMeters == 5432)
        #expect(box.value.sets[1].weightKg != 100)
        #expect(box.value.sets[1].distanceMeters != 5432)
    }

    /// Rounded to what the equipment makes in the new unit: the grid from the bar up, or a rack.
    @Test("Test Converted Weights Snap To The Gyms Increment")
    func testConvertedWeightsSnapToTheGymsIncrement() {
        let bar = WeightStep(kind: .increment(5, min: 45, max: nil), chip: nil, baseWeight: 45, plates: [Plate(weight: 2.5)])
        let rack = WeightStep(kind: .list([10, 12.5, 15]), chip: nil, baseWeight: nil, plates: [])

        #expect(bar.nearest(to: 220.46) == 220)
        #expect(bar.nearest(to: 20) == 45)
        #expect(rack.nearest(to: 13.4) == 12.5)
    }

    /// On the live tracker the swap is the tracker's: the pick is handed to it, and the exercise
    /// is left alone here, logged sets and all (`WorkoutTrackerSwapTests`).
    @Test("Test The Live Tracker Is Handed The Swap")
    func testTheLiveTrackerIsHandedTheSwap() {
        let screen = makeScreen()
        let replacement = ExerciseModel.mock
        screen.router.swapSelection = replacement
        var logged = set(id: "s1", index: 1)
        logged.completedAt = Date()
        let box = MutableExercise(exercise(sets: [logged, set(id: "s2", index: 2)]))
        var handed: [String] = []

        screen.presenter.onSwapPressed(box.binding, onSwap: { handed.append($0.id) })

        #expect(handed == [replacement.id])
        #expect(screen.router.confirmations.isEmpty)
        #expect(box.value.templateId == "template-1")
        #expect(box.value.sets.map(\.id) == ["s1", "s2"])
    }

    /// An open warm-up is not a working set, so it does not come back as one after a swap.
    @Test("Test Swapping In Place Does Not Count Open Warm-Ups")
    func testSwappingInPlaceDoesNotCountOpenWarmUps() throws {
        let screen = makeScreen()
        let replacement = try #require(ExerciseModel.mocks.first { !WorkoutSessionModel.isPerSide($0) })
        var logged = set(id: "s1", index: 2)
        logged.completedAt = Date()
        let box = MutableExercise(exercise(
            mode: WorkoutSessionModel.trackingMode(for: replacement),
            sets: [set(id: "w1", index: 1, isWarmup: true), logged, set(id: "s2", index: 3), set(id: "s3", index: 4)]
        ))

        screen.presenter.swap(box.binding, to: replacement, keepingLoggedSets: true)

        #expect(box.value.sets.count == 3)
        #expect(box.value.sets.filter { $0.completedAt == nil }.count == 2)
        #expect(!box.value.sets.contains { $0.isWarmup })
    }
}
