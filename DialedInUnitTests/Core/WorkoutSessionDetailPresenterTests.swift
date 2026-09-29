//
//  WorkoutSessionDetailPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// A finished workout, opened to read or to correct.
///
/// Editing is where the rules live. Sets and exercises carry a one-based `index` that positions them
/// in the list, so removing one has to renumber what is left — otherwise the gap persists and the
/// next set added lands on a number already taken. Adding a set copies the previous set's numbers,
/// because a user adding a fourth set of the same thing should not retype it.
///
/// The summary figures exclude warm-ups, as they do on the Workouts screen: counting them would
/// reward a longer ramp as if it were more training.
@MainActor
struct WorkoutSessionDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "author-1")
        var preferences: [String: ExerciseUnitPreference] = [:]
        private(set) var savedSessions: [WorkoutSessionModel] = []
        private(set) var deletedSessionIds: [String] = []
        private(set) var preferenceReads: [String] = []
        var saveError: Error?

        /// Exercised in `WorkoutSessionAuthorTests`; unused here.
        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }

        func saveWorkoutSession(_ session: WorkoutSessionModel) async throws {
            if let saveError { throw saveError }
            savedSessions.append(session)
        }

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferenceReads.append(templateId)
            return preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func setPreference(weightUnit: ExerciseWeightUnit?, distanceUnit: ExerciseDistanceUnit?, for templateId: String) {
            var preference = preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
            if let weightUnit { preference.weightUnit = weightUnit }
            if let distanceUnit { preference.distanceUnit = distanceUnit }
            preferences[templateId] = preference
        }

        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
        func deleteWorkoutSession(id: String) async throws {
            deletedSessionIds.append(id)
        }
    }

    private final class Router: WorkoutSessionDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        // Unguarded on purpose — see `AnalyticsRouterDouble`. The test target has no `-DDEV`, so a
        // `#if DEV || MOCK` stub disappears while the protocol requirement stays.
        func showDevSettingsView() { shown.append("devSettings") }
        func showExercisesPickerView(delegate: ExercisesPickerDelegate) { shown.append("exercisesPicker") }
    }

    private struct Screen {
        let presenter: WorkoutSessionDetailPresenter
        let interactor: Interactor
        let router: Router
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Saving happens in a detached `Task` for the timing edits, so a test has to let the loop turn.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private func set(
        _ index: Int,
        reps: Int? = 8,
        weightKg: Double? = 80,
        side: SetSide? = nil,
        isWarmup: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: isWarmup,
            dateCreated: start
        )
    }

    private func exercise(id: String, index: Int, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(id)",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: index,
            sets: sets
        )
    }

    private func session(exercises: [WorkoutExerciseModel] = [], duration: TimeInterval? = 3600) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: start,
            endedAt: duration.map { start.addingTimeInterval($0) },
            exercises: exercises
        )
    }

    /// `repsPerSide` is one of the three metrics that genuinely mean one limb at a time — see
    /// `WorkoutSessionModel.isPerSide`.
    private var perSideExerciseModel: ExerciseModel {
        ExerciseModel(
            id: "exercise-model-1",
            authorId: "author-1",
            name: "Single Arm Row",
            trackableMetrics: [.repsPerSide, .weight],
            type: .compoundUpper,
            laterality: nil,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func makeScreen(user: UserModel? = UserModel(userId: "author-1")) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        return Screen(
            presenter: WorkoutSessionDetailPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - The summary

    @Test("Test Warm-Up Sets Are Not Counted")
    func testWarmUpSetsAreNotCounted() {
        let screen = makeScreen()
        let workout = session(exercises: [exercise(id: "e1", index: 1, sets: [
            set(1, isWarmup: true),
            set(2),
            set(3)
        ])])

        #expect(screen.presenter.totalSets(session: workout) == 2)
    }

    @Test("Test Volume Is Weight Times Reps Across The Working Sets")
    func testVolumeIsWeightTimesRepsAcrossTheWorkingSets() {
        let screen = makeScreen()
        let workout = session(exercises: [exercise(id: "e1", index: 1, sets: [
            set(1, reps: 8, weightKg: 80),
            set(2, reps: 6, weightKg: 90)
        ])])

        // 640 + 540
        #expect(screen.presenter.totalVolume(session: workout) == 1180)
    }

    /// Bodyweight and timed work carry no weight or no reps, so they add no volume rather than
    /// counting as zero-weight lifts.
    @Test("Test Sets Without Weight Or Reps Add No Volume")
    func testSetsWithoutWeightOrRepsAddNoVolume() {
        let screen = makeScreen()
        let workout = session(exercises: [exercise(id: "e1", index: 1, sets: [
            set(1, reps: 12, weightKg: nil),
            set(2, reps: nil, weightKg: 80)
        ])])

        #expect(screen.presenter.totalVolume(session: workout) == 0)
    }

    /// A session with no volume to show reads as a dash rather than "0 kg", which would look like a
    /// measurement rather than an absence.
    @Test("Test No Volume Reads As A Dash")
    func testNoVolumeReadsAsADash() {
        let screen = makeScreen()

        #expect(screen.presenter.volumeFormatted(session: session()) == "—")
        #expect(screen.presenter.volumeFormatted(
            session: session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        ) == "640 kg")
    }

    // MARK: - Whose workout it is

    @Test("Test Only The Author Owns The Workout")
    func testOnlyTheAuthorOwnsTheWorkout() {
        let screen = makeScreen(user: UserModel(userId: "author-1"))

        #expect(screen.presenter.isAuthor(sessionAuthorId: "author-1"))
        #expect(!screen.presenter.isAuthor(sessionAuthorId: "someone-else"))
    }

    /// A signed-out reader owns nothing, so a nil author must not match a nil user.
    @Test("Test A Missing User Owns Nothing")
    func testAMissingUserOwnsNothing() {
        let screen = makeScreen(user: nil)

        #expect(!screen.presenter.isAuthor(sessionAuthorId: nil))
    }

    @Test("Test Unsaved Changes Are The Difference From What Was Opened")
    func testUnsavedChangesAreTheDifferenceFromWhatWasOpened() {
        let screen = makeScreen()
        let original = session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        var edited = original
        edited.name = "Pull Day"

        #expect(!screen.presenter.hasUnsavedChanges(session: original, editedSession: original))
        #expect(screen.presenter.hasUnsavedChanges(session: original, editedSession: edited))
    }

    // MARK: - Adding a set

    /// A fourth set of the same thing should not have to be retyped.
    @Test("Test A New Set Copies The One Before It")
    func testANewSetCopiesTheOneBeforeIt() throws {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1, reps: 6, weightKg: 100)])]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        let added = try #require(workout.value.exercises.first?.sets.last)
        #expect(added.reps == 6)
        #expect(added.weightKg == 100)
        #expect(added.index == 2)
    }

    /// A set added to an exercise with none is a blank one, not a crash.
    @Test("Test The First Set Of An Exercise Has Nothing To Copy")
    func testTheFirstSetOfAnExerciseHasNothingToCopy() throws {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [])]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        let added = try #require(workout.value.exercises.first?.sets.first)
        #expect(added.reps == nil)
        #expect(added.index == 1)
    }

    /// A warm-up is something the user marks deliberately; copying its flag would make every set
    /// after the ramp a warm-up too.
    @Test("Test A New Set Is Never A Warm-Up")
    func testANewSetIsNeverAWarmUp() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1, isWarmup: true)])]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        #expect(workout.value.exercises.first?.sets.last?.isWarmup == false)
    }

    @Test("Test Adding To An Exercise That Is Not There Changes Nothing")
    func testAddingToAnExerciseThatIsNotThereChangesNothing() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.addSet(session: workout.binding, to: "missing")

        #expect(workout.value.exercises.first?.sets.count == 1)
    }

    /// The new set is authored by whoever is signed in, so a signed-out reader adds nothing.
    @Test("Test Adding A Set Needs A Signed-In User")
    func testAddingASetNeedsASignedInUser() {
        let screen = makeScreen(user: nil)
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        #expect(workout.value.exercises.first?.sets.count == 1)
    }

    // MARK: - Removing a set

    @Test("Test Deleting A Set Removes It")
    func testDeletingASetRemovesIt() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2), set(3)])]))

        screen.presenter.deleteSet(session: workout.binding, "set-2", from: "e1")

        #expect(workout.value.exercises.first?.sets.map(\.id) == ["set-1", "set-3"])
    }

    /// The gap has to close, or the numbers on screen skip and the next set added collides with one
    /// that is already there.
    @Test("Test Deleting A Set Renumbers The Rest")
    func testDeletingASetRenumbersTheRest() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1), set(2), set(3)])]))

        screen.presenter.deleteSet(session: workout.binding, "set-1", from: "e1")

        #expect(workout.value.exercises.first?.sets.map(\.index) == [1, 2])
    }

    @Test("Test Deleting A Set That Is Not There Changes Nothing")
    func testDeletingASetThatIsNotThereChangesNothing() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.deleteSet(session: workout.binding, "missing", from: "e1")

        #expect(workout.value.exercises.first?.sets.count == 1)
    }

    // MARK: - Sets worked a side at a time

    /// Three sets of a single-arm row, logged as the six rows they take: left then right, each row
    /// numbered for itself.
    private var threeSetsPerSide: [WorkoutSetModel] {
        [
            set(1, reps: 10, weightKg: 20, side: .left), set(2, reps: 9, weightKg: 22, side: .right),
            set(3, reps: 10, weightKg: 20, side: .left), set(4, reps: 8, weightKg: 22, side: .right)
        ]
    }

    /// A fourth set of a single-arm row is two efforts, so adding one has to hand the user both.
    @Test("Test Adding A Set To A Per-Side Exercise Adds A Pair")
    func testAddingASetToAPerSideExerciseAddsAPair() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        let sets = workout.value.exercises.first?.sets ?? []
        #expect(sets.count == 6)
        #expect(sets.suffix(2).map(\.side) == [.left, .right])
    }

    /// The arms lift different weights, so the new left copies the last left and the new right the
    /// last right — copying whichever row happened to be last would show one arm the other's work.
    @Test("Test Each Half Of A New Pair Copies Its Own Side")
    func testEachHalfOfANewPairCopiesItsOwnSide() throws {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        let added = Array((workout.value.exercises.first?.sets ?? []).suffix(2))
        let left = try #require(added.first)
        let right = try #require(added.last)
        #expect(left.weightKg == 20)
        #expect(left.reps == 10)
        #expect(right.weightKg == 22)
        #expect(right.reps == 8)
    }

    /// Sides are told apart by `side`, never by sharing a number, so each new row takes the next
    /// free index.
    @Test("Test Both Halves Of A New Pair Get Their Own Index")
    func testBothHalvesOfANewPairGetTheirOwnIndex() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        #expect(workout.value.exercises.first?.sets.map(\.index) == [1, 2, 3, 4, 5, 6])
    }

    /// A two-sided exercise gains one row with no side at all, as it always did.
    @Test("Test Adding A Set To A Two-Sided Exercise Adds One Sideless Row")
    func testAddingASetToATwoSidedExerciseAddsOneSidelessRow() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.addSet(session: workout.binding, to: "e1")

        let sets = workout.value.exercises.first?.sets ?? []
        #expect(sets.count == 2)
        #expect(sets.last?.side == nil)
    }

    /// A stranded limb numbers, counts and rests as a set of its own, claiming work that was never
    /// done — so removing either half removes the pair.
    @Test("Test Deleting One Half Of A Pair Removes Both")
    func testDeletingOneHalfOfAPairRemovesBoth() {
        let screen = makeScreen()
        let fromLeft = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))
        let fromRight = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))

        screen.presenter.deleteSet(session: fromLeft.binding, "set-1", from: "e1")
        screen.presenter.deleteSet(session: fromRight.binding, "set-2", from: "e1")

        #expect(fromLeft.value.exercises.first?.sets.map(\.id) == ["set-3", "set-4"])
        #expect(fromRight.value.exercises.first?.sets.map(\.id) == ["set-3", "set-4"])
    }

    /// Renumbering after a pair goes still has to leave one index per row, or the next set added
    /// lands on a number already taken.
    @Test("Test Deleting A Pair Leaves The Rest Uniquely Numbered")
    func testDeletingAPairLeavesTheRestUniquelyNumbered() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: threeSetsPerSide)]))

        screen.presenter.deleteSet(session: workout.binding, "set-3", from: "e1")

        #expect(workout.value.exercises.first?.sets.map(\.index) == [1, 2])
        #expect(workout.value.exercises.first?.sets.map(\.side) == [.left, .right])
    }

    // MARK: - Removing an exercise

    @Test("Test Deleting An Exercise Removes It And Renumbers The Rest")
    func testDeletingAnExerciseRemovesItAndRenumbersTheRest() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1)]),
            exercise(id: "e2", index: 2, sets: [set(2)]),
            exercise(id: "e3", index: 3, sets: [set(3)])
        ]))

        screen.presenter.deleteExercise(session: workout.binding, id: "e1")

        #expect(workout.value.exercises.map(\.id) == ["e2", "e3"])
        #expect(workout.value.exercises.map(\.index) == [1, 2])
    }

    @Test("Test Replacing An Exercise Keeps Its Place")
    func testReplacingAnExerciseKeepsItsPlace() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [
            exercise(id: "e1", index: 1, sets: [set(1)]),
            exercise(id: "e2", index: 2, sets: [set(2)])
        ]))
        var replacement = exercise(id: "e2", index: 2, sets: [set(2)])
        replacement.name = "Incline Press"

        screen.presenter.updateExercise(session: workout.binding, at: 1, with: replacement)

        #expect(workout.value.exercises.map(\.name) == ["Bench Press", "Incline Press"])
    }

    @Test("Test Replacing An Exercise Out Of Range Changes Nothing")
    func testReplacingAnExerciseOutOfRangeChangesNothing() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.updateExercise(session: workout.binding, at: 7, with: exercise(id: "e9", index: 9, sets: []))

        #expect(workout.value.exercises.map(\.id) == ["e1"])
    }

    // MARK: - Unit preferences

    @Test("Test Entering Edit Mode Loads A Preference For Every Exercise")
    func testEnteringEditModeLoadsAPreferenceForEveryExercise() {
        let screen = makeScreen()
        let workout = session(exercises: [
            exercise(id: "e1", index: 1, sets: []),
            exercise(id: "e2", index: 2, sets: [])
        ])

        screen.presenter.enterEditMode(session: workout)

        #expect(screen.presenter.exerciseUnitPreferences.count == 2)
        #expect(screen.interactor.preferenceReads.sorted() == ["template-e1", "template-e2"])
    }

    /// The preference is read once and kept, so scrolling a long session does not hit the manager
    /// for every row.
    @Test("Test A Preference Is Read Once And Cached")
    func testAPreferenceIsReadOnceAndCached() {
        let screen = makeScreen()

        _ = screen.presenter.getUnitPreference(for: "template-e1")
        _ = screen.presenter.getUnitPreference(for: "template-e1")

        #expect(screen.interactor.preferenceReads == ["template-e1"])
    }

    @Test("Test Changing The Weight Unit Keeps The Distance Unit")
    func testChangingTheWeightUnitKeepsTheDistanceUnit() {
        let screen = makeScreen()
        screen.interactor.preferences["template-e1"] = ExerciseUnitPreference(
            exerciseModelId: "template-e1",
            weightUnit: .kilograms,
            distanceUnit: .miles
        )

        screen.presenter.updateWeightUnit(.pounds, for: "template-e1")

        let stored = screen.interactor.preferences["template-e1"]
        #expect(stored?.weightUnit == .pounds)
        #expect(stored?.distanceUnit == .miles)
    }

    @Test("Test Changing The Distance Unit Keeps The Weight Unit")
    func testChangingTheDistanceUnitKeepsTheWeightUnit() {
        let screen = makeScreen()
        screen.interactor.preferences["template-e1"] = ExerciseUnitPreference(
            exerciseModelId: "template-e1",
            weightUnit: .pounds,
            distanceUnit: .meters
        )

        screen.presenter.updateDistanceUnit(.miles, for: "template-e1")

        let stored = screen.interactor.preferences["template-e1"]
        #expect(stored?.weightUnit == .pounds)
        #expect(stored?.distanceUnit == .miles)
    }

    // MARK: - Timing

    /// Moving the start moves the end with it, so correcting when a workout began does not silently
    /// change how long it lasted.
    @Test("Test Moving The Start Keeps The Duration")
    func testMovingTheStartKeepsTheDuration() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        let newStart = start.addingTimeInterval(7200)

        screen.presenter.onStartTimeChanged(newStart, session: workout.binding)
        await settle()

        #expect(workout.value.dateCreated == newStart)
        #expect(workout.value.endedAt == newStart.addingTimeInterval(3600))
        #expect(screen.interactor.savedSessions.count == 1)
    }

    @Test("Test Editing The Duration Starts From What The Session Lasted")
    func testEditingTheDurationStartsFromWhatTheSessionLasted() {
        let screen = makeScreen()

        screen.presenter.onEditDurationPressed(session: session(duration: 5400))

        #expect(screen.presenter.durationHours == 1)
        #expect(screen.presenter.durationMinutes == 30)
        #expect(screen.presenter.isEditingDuration)
    }

    @Test("Test Confirming A Duration Moves The End")
    func testConfirmingADurationMovesTheEnd() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        screen.presenter.durationHours = 2
        screen.presenter.durationMinutes = 15

        screen.presenter.onDurationConfirmed(session: workout.binding)
        await settle()

        #expect(workout.value.endedAt == start.addingTimeInterval(2 * 3600 + 15 * 60))
        #expect(!screen.presenter.isEditingDuration)
    }

    /// A zero duration would put the end before the beginning, so it is refused rather than saved.
    @Test("Test A Zero Duration Is Refused")
    func testAZeroDurationIsRefused() async {
        let screen = makeScreen()
        let workout = MutableSession(session(duration: 3600))
        screen.presenter.durationHours = 0
        screen.presenter.durationMinutes = 0

        screen.presenter.onDurationConfirmed(session: workout.binding)
        await settle()

        #expect(workout.value.endedAt == start.addingTimeInterval(3600))
        #expect(screen.interactor.savedSessions.isEmpty)
    }

    // MARK: - Saving

    /// Opening an edit and changing nothing should not write, so an untouched session keeps its
    /// modification date.
    @Test("Test Saving Without A Change Writes Nothing")
    func testSavingWithoutAChangeWritesNothing() async {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))
        let original = workout.value

        await screen.presenter.saveChanges(initialSession: original, session: workout.binding)

        #expect(screen.interactor.savedSessions.isEmpty)
        #expect(!screen.presenter.isEditMode)
    }

    @Test("Test Saving A Change Writes It")
    func testSavingAChangeWritesIt() async {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))
        let original = workout.value
        workout.value.name = "Pull Day"

        await screen.presenter.saveChanges(initialSession: original, session: workout.binding)

        #expect(screen.interactor.savedSessions.map(\.name) == ["Pull Day"])
        #expect(!screen.presenter.isEditMode)
    }

    /// A failed save leaves the user in edit mode with their work, rather than dropping it.
    @Test("Test A Failed Save Keeps The User In Edit Mode")
    func testAFailedSaveKeepsTheUserInEditMode() async {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))
        let original = workout.value
        workout.value.name = "Pull Day"
        screen.presenter.enterEditMode(session: workout.value)
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        await screen.presenter.saveChanges(initialSession: original, session: workout.binding)

        #expect(screen.presenter.isEditMode)
        #expect(!screen.presenter.isSaving)
    }

    // MARK: - Deleting

    @Test("Test Deleting The Workout Removes It")
    func testDeletingTheWorkoutRemovesIt() async {
        let screen = makeScreen()

        screen.presenter.deleteSession(session: session())
        await settle()

        #expect(screen.interactor.deletedSessionIds == ["session-1"])
    }

    // MARK: - Adding exercises

    @Test("Test Adding An Exercise Opens The Picker")
    func testAddingAnExerciseOpensThePicker() {
        let screen = makeScreen()

        screen.presenter.onAddExercisePressed()

        #expect(screen.router.shown == ["exercisesPicker"])
    }

    @Test("Test Picked Exercises Are Appended And The Selection Cleared")
    func testPickedExercisesAreAppendedAndTheSelectionCleared() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))
        screen.presenter.selectedExerciseModels = [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]

        screen.presenter.addSelectedExercises(session: workout.binding)

        #expect(workout.value.exercises.count == 2)
        #expect(workout.value.exercises.map(\.index) == [1, 2])
        #expect(screen.presenter.selectedExerciseModels.isEmpty)
    }

    /// A single-arm exercise added to a finished session has no rows yet to read a side off, so the
    /// exercise decides. Joining as sideless rows would leave it unable to gain a side at all.
    @Test("Test A Picked Per-Side Exercise Joins With Sided Sets")
    func testAPickedPerSideExerciseJoinsWithSidedSets() {
        let screen = makeScreen()
        let workout = MutableSession(session())
        screen.presenter.selectedExerciseModels = [
            WorkoutTemplateExercise(exercise: perSideExerciseModel, setRestTimers: false)
        ]

        screen.presenter.addSelectedExercises(session: workout.binding)

        #expect(workout.value.exercises.first?.sets.map(\.side) == [.left, .right])
    }

    /// A two-sided exercise still joins with one row per set.
    @Test("Test A Picked Two-Sided Exercise Joins With Sideless Sets")
    func testAPickedTwoSidedExerciseJoinsWithSidelessSets() {
        let screen = makeScreen()
        let workout = MutableSession(session())
        screen.presenter.selectedExerciseModels = [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]

        screen.presenter.addSelectedExercises(session: workout.binding)

        #expect(workout.value.exercises.first?.sets.allSatisfy { $0.side == nil } == true)
    }

    @Test("Test Adding Nothing Changes Nothing")
    func testAddingNothingChangesNothing() {
        let screen = makeScreen()
        let workout = MutableSession(session(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])]))

        screen.presenter.addSelectedExercises(session: workout.binding)

        #expect(workout.value.exercises.count == 1)
    }

    // MARK: - Helpers

    /// A session held by reference, so the presenter's editing methods — which all take a
    /// `Binding` — can be driven without a view, and the result read back afterwards.
    @MainActor
    private final class MutableSession {
        var value: WorkoutSessionModel

        init(_ value: WorkoutSessionModel) {
            self.value = value
        }

        /// `Binding`'s accessors are `@Sendable`, so they cannot carry this class's isolation and
        /// the capture has to be safe on its own terms. Being main-actor isolated makes the class
        /// `Sendable`; the accessors then assume the isolation rather than hop, which holds because
        /// every presenter method that reads or writes one of these bindings is `@MainActor` too.
        var binding: Binding<WorkoutSessionModel> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }
}
