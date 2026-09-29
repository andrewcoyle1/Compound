//
//  WorkoutTrackingRowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// One row of a live workout: the set being lifted right now.
///
/// This is the screen the user actually touches between sets, and it owns three things that go
/// wrong quietly — whether a set is allowed to be marked done, how long the rest timer that fires
/// afterwards runs for, and which of the several rest durations the picker is showing. A row is
/// rebuilt per set, so anything it holds in memory is per-row state, and anything it reads has to
/// come back from the interactor the same way twice.
@MainActor
struct SetTrackerRowPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, SetTrackerRowInteractor {
        var workoutSettings: WorkoutSettings = WorkoutSettings(authorId: "user-1")
        var favouriteGymProfile: GymProfileModel?
        var allExercises: [ExerciseModel] = []
        var preferences: [String: ExerciseUnitPreference] = [:]
        var restOverrides: [String: Int] = [:]

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func exerciseRestOverride(for exerciseId: String) -> Int? {
            restOverrides[exerciseId]
        }
    }

    /// `dismissModal()` is a `GlobalRouter` extension and not restated by `SetTrackerRowRouter`,
    /// so it dispatches statically and never reaches this double. The rest-picker tests drive the
    /// captured Save action and assert the duration it stored instead.
    private final class Router: SetTrackerRowRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var restPrimaryAction: (() -> Void)?
        private(set) var restMinutes: Binding<Int>?
        private(set) var restSeconds: Binding<Int>?

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
            restPrimaryAction = primaryButtonAction
            restMinutes = minutesSelection
            restSeconds = secondsSelection
        }
    }

    /// Holds a value the presenter edits through a `Binding`, so its methods can be driven without
    /// a view and the result read back. Main-actor isolated so it is `Sendable`, which `Binding`'s
    /// `@Sendable` accessors require.
    @MainActor
    private final class Box<Value> {
        var value: Value

        init(_ value: Value) {
            self.value = value
        }

        var binding: Binding<Value> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    private struct Screen {
        let presenter: SetTrackerRowPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: SetTrackerRowPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func set(
        id: String = "set-1",
        index: Int = 1,
        reps: Int? = 10,
        weightKg: Double? = 100,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date? = nil
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
            completedAt: completedAt,
            dateCreated: Date()
        )
    }

    private func exercise(
        templateId: String = "template-1",
        mode: TrackingMode = .weightReps,
        sets: [WorkoutSetModel] = []
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

    private func exerciseModel(id: String, type: ExerciseType) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "user-1",
            name: "Bench Press",
            trackableMetrics: [.weight, .reps],
            type: type,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    // MARK: - Marking a set done

    @Test("Test Completing A Set Stamps The Time")
    func testCompletingASetStampsTheTime() {
        let screen = makeScreen()
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(box.value.completedAt != nil)
    }

    /// The tick is a toggle — tapping a set that is already done undoes it, which is how a set
    /// logged by mistake is taken back.
    @Test("Test Tapping A Completed Set Undoes It")
    func testTappingACompletedSetUndoesIt() {
        let screen = makeScreen()
        let box = Box(set(completedAt: Date()))

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(box.value.completedAt == nil)
    }

    /// A set with no reps entered has not been lifted, so it must not be stamped as done however
    /// hard the tick is pressed — a completed-but-empty set becomes a zero in the training history.
    @Test("Test A Set With No Reps Is Not Marked Done")
    func testASetWithNoRepsIsNotMarkedDone() {
        let screen = makeScreen()
        let box = Box(set(reps: nil))

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(box.value.completedAt == nil)
    }

    /// A negative weight is a typo, not a lift, so it is refused even though reps are present.
    @Test("Test A Negative Weight Is Refused")
    func testANegativeWeightIsRefused() {
        let screen = makeScreen()
        let box = Box(set(weightKg: -20))

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(box.value.completedAt == nil)
    }

    /// A run needs both halves before it counts.
    @Test("Test A Distance Set Is Refused Without A Time")
    func testADistanceSetIsRefusedWithoutATime() {
        let screen = makeScreen()
        let box = Box(set(reps: nil, weightKg: nil, distanceMeters: 5000))

        screen.presenter.onSetComplete(exercise(mode: .distanceTime), box.binding)

        #expect(box.value.completedAt == nil)
    }

    // MARK: - The rest that follows

    @Test("Test Completing A Set Starts The Rest Timer")
    func testCompletingASetStartsTheRestTimer() {
        let screen = makeScreen()
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started == [90])
    }

    /// Someone who trains without a timer gets their set logged and nothing else — a rest screen
    /// appearing uninvited is the whole reason the setting exists.
    @Test("Test No Rest Starts When Rest Timers Are Off")
    func testNoRestStartsWhenRestTimersAreOff() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.useRestTimers = false
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(box.value.completedAt != nil)
        #expect(started.isEmpty)
    }

    /// Undoing a set must not start a rest — the user is correcting a mistake, not finishing work.
    @Test("Test Undoing A Set Starts No Rest")
    func testUndoingASetStartsNoRest() {
        let screen = makeScreen()
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set(completedAt: Date()))

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started.isEmpty)
    }

    /// Heavy compound work is rested longer than accessory work, which is what the per-type
    /// override is for.
    @Test("Test The Exercise Type Override Sets The Rest Length")
    func testTheExerciseTypeOverrideSetsTheRestLength() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .compoundLower)]
        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started == [240])
    }

    /// A rest set by hand on this set beats the type override, which beats the global default.
    @Test("Test A Custom Rest Beats The Type Override")
    func testACustomRestBeatsTheTypeOverride() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .compoundLower)]
        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]
        screen.presenter.updateRestBefore(setId: "set-1", seconds: 45)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started == [45])
    }

    /// The narrowest setting wins: a rest set on this one exercise is more specific than the one
    /// set for everything of its type, which is more specific than the global default.
    @Test("Test The Per-Exercise Override Beats The Type Override")
    func testThePerExerciseOverrideBeatsTheTypeOverride() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .compoundLower)]
        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]
        screen.interactor.restOverrides = ["template-1": 150]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started == [150])
    }

    /// No override is the state every existing user is in, and it has to leave the rest exactly
    /// where it was — on the type override, or on the global default behind it.
    @Test("Test No Per-Exercise Override Leaves The Rest Alone")
    func testNoPerExerciseOverrideLeavesTheRestAlone() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .compoundLower)]
        screen.interactor.restOverrides = [:]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(), Box(set()).binding)
        #expect(started == [90])

        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]
        screen.presenter.onSetComplete(exercise(), Box(set(id: "set-2")).binding)
        #expect(started == [90, 240])
    }

    /// An override belongs to one exercise, not to whatever exercise is on screen.
    @Test("Test Another Exercises Override Does Not Apply")
    func testAnotherExercisesOverrideDoesNotApply() {
        let screen = makeScreen()
        screen.interactor.restOverrides = ["template-2": 150]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(), Box(set()).binding)

        #expect(started == [90])
    }

    /// A zero-second override is a leftover from a build that stored an empty picker as a literal
    /// zero. Resting for no time is not something the user asked for, so it falls through.
    @Test("Test A Zero Per-Exercise Override Is Not An Override")
    func testAZeroPerExerciseOverrideIsNotAnOverride() {
        let screen = makeScreen()
        screen.interactor.restOverrides = ["template-1": 0]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(), Box(set()).binding)

        #expect(started == [90])
    }

    /// A rest typed on the set itself is narrower still, and beats even the per-exercise one.
    @Test("Test A Custom Rest Beats The Per-Exercise Override")
    func testACustomRestBeatsThePerExerciseOverride() {
        let screen = makeScreen()
        screen.interactor.restOverrides = ["template-1": 150]
        screen.presenter.updateRestBefore(setId: "set-1", seconds: 45)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(), Box(set()).binding)

        #expect(started == [45])
    }

    /// An override for a different kind of lift is not this lift's rest.
    @Test("Test An Unrelated Type Override Does Not Apply")
    func testAnUnrelatedTypeOverrideDoesNotApply() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .core)]
        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(started == [90])
    }

    // MARK: - Where the set sits changes the rest

    /// Warm-ups are a ramp, not work: nothing rests between them, whatever the scaling.
    @Test("Test Warm-Ups Never Rest Between Themselves")
    func testWarmUpsNeverRestBetweenThemselves() {
        let screen = makeScreen()
        let warmup = set(id: "w1", index: 1, isWarmup: true)
        let box = Box(warmup)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(
            exercise(sets: [warmup, set(id: "w2", index: 2, isWarmup: true), set(id: "s1", index: 3)]),
            box.binding
        )

        #expect(box.value.completedAt != nil)
        #expect(started.isEmpty)
    }

    /// The one warm-up rest is after the last one, before the first working set, and it is on by
    /// default at the warm-up scaling: 90 at 0.75.
    @Test("Test The Last Warm-Up Rests For A Fraction Of The Working Rest By Default")
    func testTheLastWarmUpRestsForAFractionOfTheWorkingRestByDefault() {
        let screen = makeScreen()
        let last = set(id: "w2", index: 2, isWarmup: true)
        let box = Box(last)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(
            exercise(sets: [set(id: "w1", index: 1, isWarmup: true), last, set(id: "s1", index: 3)]),
            box.binding
        )

        #expect(started == [68])
    }

    @Test("Test The Last Warm-Up Rests Not At All When Turned Off")
    func testTheLastWarmUpRestsNotAtAllWhenTurnedOff() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.restAfterLastWarmUp = false
        let last = set(id: "w2", index: 2, isWarmup: true)
        let box = Box(last)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(
            exercise(sets: [set(id: "w1", index: 1, isWarmup: true), last, set(id: "s1", index: 3)]),
            box.binding
        )

        #expect(box.value.completedAt != nil)
        #expect(started.isEmpty)
    }

    /// The gap after the last set is the walk to the next exercise, which is its own setting.
    @Test("Test The Last Set Rests At The Between-Exercises Scaling")
    func testTheLastSetRestsAtTheBetweenExercisesScaling() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.betweenExercisesRestScaling = 0.5
        let last = set(id: "s2", index: 2)
        let box = Box(last)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(sets: [set(id: "s1", index: 1), last]), box.binding)

        #expect(started == [45])
    }

    @Test("Test The Last Set Rests Not At All When Turned Off")
    func testTheLastSetRestsNotAtAllWhenTurnedOff() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.restBetweenExercises = false
        let last = set(id: "s2", index: 2)
        let box = Box(last)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(sets: [set(id: "s1", index: 1), last]), box.binding)

        #expect(box.value.completedAt != nil)
        #expect(started.isEmpty)
    }

    /// A set in the middle of an exercise is the one that actually needs the full rest, so none of
    /// the scalings touch it.
    @Test("Test A Set Between Others Rests At Full Length")
    func testASetBetweenOthersRestsAtFullLength() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.warmUpRestScaling = 0.25
        screen.interactor.workoutSettings.betweenExercisesRestScaling = 0.25
        let middle = set(id: "s2", index: 2)
        let box = Box(middle)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(
            exercise(sets: [set(id: "s1", index: 1), middle, set(id: "s3", index: 3)]),
            box.binding
        )

        #expect(started == [90])
    }

    /// A rest typed for this set is what the user asked for, so no scaling is applied on top.
    @Test("Test A Hand-Set Rest Is Not Scaled")
    func testAHandSetRestIsNotScaled() {
        let screen = makeScreen()
        let warmup = set(id: "w1", index: 1, isWarmup: true)
        screen.presenter.updateRestBefore(setId: "w1", seconds: 45)
        let box = Box(warmup)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(exercise(sets: [warmup, set(id: "s1", index: 2)]), box.binding)

        #expect(started == [45])
    }

    /// Scaling a rest to nothing means no rest, not a zero-second one that fires and ends.
    @Test("Test Scaling To Zero Means No Rest")
    func testScalingToZeroMeansNoRest() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.warmUpRestScaling = 0
        let last = set(id: "w2", index: 2, isWarmup: true)
        let box = Box(last)
        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }

        screen.presenter.onSetComplete(
            exercise(sets: [set(id: "w1", index: 1, isWarmup: true), last, set(id: "s1", index: 3)]),
            box.binding
        )

        #expect(started.isEmpty)
    }

    // MARK: - The rest picker

    /// The one that used to be wrong. Swiping a row opens the picker on the rest that would
    /// actually run, so someone with a four-minute override for squats is not shown ninety
    /// seconds and does not quietly cut their rest in half by pressing Save.
    @Test("Test The Picker Opens On The Rest That Would Actually Run")
    func testThePickerOpensOnTheRestThatWouldActuallyRun() {
        let screen = makeScreen()
        screen.interactor.allExercises = [exerciseModel(id: "template-1", type: .compoundLower)]
        screen.interactor.workoutSettings.restDurationsByExerciseType = [ExerciseType.compoundLower.rawValue: 240]

        screen.presenter.onRestPickerRequested(exercise: exercise(), setId: "set-1")

        #expect(screen.presenter.restPickerMinutesSelection == 4)
        #expect(screen.presenter.restPickerSecondsSelection == 0)
    }

    @Test("Test The Picker Opens On A Rest Already Set By Hand")
    func testThePickerOpensOnARestAlreadySetByHand() {
        let screen = makeScreen()
        screen.presenter.updateRestBefore(setId: "set-1", seconds: 135)

        screen.presenter.onRestPickerRequested(exercise: exercise(), setId: "set-1")

        #expect(screen.presenter.restPickerMinutesSelection == 2)
        #expect(screen.presenter.restPickerSecondsSelection == 15)
        #expect(screen.router.shown == ["rest"])
    }

    /// Saving the wheels stores a rest for this set alone, and the next set completed uses it.
    @Test("Test Saving The Picker Stores The Chosen Rest")
    func testSavingThePickerStoresTheChosenRest() {
        let screen = makeScreen()
        screen.presenter.onRestPickerRequested(exercise: exercise(), setId: "set-1")
        screen.router.restMinutes?.wrappedValue = 2
        screen.router.restSeconds?.wrappedValue = 15
        screen.router.restPrimaryAction?()

        var started: [Int] = []
        screen.presenter.onStartRest = { started.append($0) }
        let box = Box(set())
        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(screen.presenter.restBeforeSetIdToSec["set-1"] == 135)
        #expect(started == [135])
    }

    /// Winding both wheels to zero means "no custom rest", so the set falls back to the settings
    /// rather than resting for no time at all.
    @Test("Test Saving Zero Clears The Custom Rest")
    func testSavingZeroClearsTheCustomRest() {
        let screen = makeScreen()
        screen.presenter.updateRestBefore(setId: "set-1", seconds: 45)
        screen.presenter.onRestPickerRequested(exercise: exercise(), setId: "set-1")
        screen.router.restMinutes?.wrappedValue = 0
        screen.router.restSeconds?.wrappedValue = 0
        screen.router.restPrimaryAction?()

        #expect(screen.presenter.restBeforeSetIdToSec["set-1"] == nil)
    }

    @Test("Test The Warmup Explanation Opens")
    func testTheWarmupExplanationOpens() {
        let screen = makeScreen()

        screen.presenter.onWarmupSetHelpPressed()

        #expect(screen.router.shown == ["warmupInfo"])
    }

    // MARK: - Deleting

    @Test("Test Deleting A Set Removes Only That One")
    func testDeletingASetRemovesOnlyThatOne() {
        let screen = makeScreen()
        let box = Box(exercise(sets: [
            set(id: "s1", index: 1), set(id: "s2", index: 2), set(id: "s3", index: 3)
        ]))

        screen.presenter.deleteSet(setId: "s2", exercise: box.binding)

        #expect(box.value.sets.map(\.id) == ["s1", "s3"])
    }

    // MARK: - When the tick is available

    /// Bodyweight work is logged at no weight, so a missing weight is allowed where missing reps
    /// are not.
    @Test("Test The Tick Needs Reps But Not A Weight")
    func testTheTickNeedsRepsButNotAWeight() {
        let screen = makeScreen()

        #expect(screen.presenter.canComplete(trackingMode: .weightReps, set: set(weightKg: nil)))
        #expect(!screen.presenter.canComplete(trackingMode: .weightReps, set: set(reps: 0)))
        #expect(!screen.presenter.canComplete(trackingMode: .weightReps, set: set(reps: nil)))
    }

    @Test("Test Each Tracking Mode Asks For Its Own Figures")
    func testEachTrackingModeAsksForItsOwnFigures() {
        let screen = makeScreen()
        let timed = set(reps: nil, weightKg: nil, durationSec: 30)
        let run = set(reps: nil, weightKg: nil, durationSec: 1500, distanceMeters: 5000)

        #expect(screen.presenter.canComplete(trackingMode: .repsOnly, set: set(weightKg: nil)))
        #expect(screen.presenter.canComplete(trackingMode: .timeOnly, set: timed))
        #expect(!screen.presenter.canComplete(trackingMode: .timeOnly, set: set()))
        #expect(screen.presenter.canComplete(trackingMode: .distanceTime, set: run))
        #expect(!screen.presenter.canComplete(trackingMode: .distanceTime, set: timed))
    }

    /// A completed set stays green even if its figures would no longer pass, so editing a logged
    /// set does not make it look undone.
    @Test("Test The Tick Colour Follows The Sets State")
    func testTheTickColourFollowsTheSetsState() {
        let screen = makeScreen()

        #expect(screen.presenter.buttonColor(set: set(completedAt: Date()), canComplete: false) == .green)
        #expect(screen.presenter.buttonColor(set: set(), canComplete: true) == .secondary)
        #expect(screen.presenter.buttonColor(set: set(), canComplete: false) != .green)
    }

    // MARK: - Units

    /// A row redraws on every keystroke in the weight field, so the preference is read once and
    /// cached rather than fetched per redraw.
    @Test("Test A Unit Preference Is Read Once And Cached")
    func testAUnitPreferenceIsReadOnceAndCached() {
        let screen = makeScreen()
        screen.interactor.preferences["template-1"] = ExerciseUnitPreference(
            exerciseModelId: "template-1",
            weightUnit: .pounds
        )
        let model = exercise()

        let first = screen.presenter.getUnitPreference(for: model)
        screen.interactor.preferences["template-1"] = ExerciseUnitPreference(
            exerciseModelId: "template-1",
            weightUnit: .kilograms
        )
        let second = screen.presenter.getUnitPreference(for: model)

        #expect(first.weightUnit == .pounds)
        #expect(second.weightUnit == .pounds)
    }

    // MARK: - Analytics

    @Test("Test Completing A Set Is Recorded")
    func testCompletingASetIsRecorded() {
        let screen = makeScreen()
        let box = Box(set())

        screen.presenter.onSetComplete(exercise(), box.binding)

        #expect(screen.interactor.trackedEventNames.contains("SetTrackerRow_SetCompleted"))
    }

    @Test("Test The Row Records Appearing And Disappearing")
    func testTheRowRecordsAppearingAndDisappearing() {
        let screen = makeScreen()
        let exerciseBox = Box(exercise())
        let setBox = Box(set())
        let delegate = SetTrackerRowDelegate(
            exercise: exerciseBox.binding,
            set: setBox.binding,
            lastSet: nil
        )

        screen.presenter.onViewAppear(delegate: delegate)
        screen.presenter.onViewDisappear(delegate: delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["SetTrackerRowView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["SetTrackerRowView_Disappear"])
    }
}
