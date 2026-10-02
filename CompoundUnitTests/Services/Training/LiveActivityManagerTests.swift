//
//  LiveActivityManagerTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

private typealias Position = LiveActivityManager.ExercisePosition

/// The Live Activity updater, seen through what it reports.
extension WorkoutRestSharedStateTests {

@MainActor
struct LiveActivityManagerTests {

    /// The lookup answers nil, as the system does in a test process: there is no activity to find.
    private func makeManager() -> (LiveActivityManager, SpyLogService) {
        let spy = SpyLogService()
        return (LiveActivityManager(logger: LogManager(services: [spy]), activityLookup: { _ in nil }), spy)
    }

    private func params(isActive: Bool = true) -> LiveActivityUpdateParams {
        LiveActivityUpdateParams(
            session: WorkoutSessionModel(
                id: "s1",
                authorId: "author-1",
                name: "Upper",
                dateCreated: Date(timeIntervalSince1970: 1_772_000_000),
                exercises: []
            ),
            isActive: isActive,
            currentExerciseIndex: 0,
            restEndsAt: nil
        )
    }

    /// With no Live Activity to update, the update fell out of an `if` with nothing logged: a
    /// Start and no terminal event, so a Live Activity that stopped updating mid-workout was
    /// invisible.
    @Test("Test Updating With No Live Activity Reports The Failure")
    func testUpdatingWithNoLiveActivityReportsTheFailure() {
        let (manager, spy) = makeManager()

        manager.updateLiveActivity(params: params())

        #expect(spy.trackedEventNames == [
            "LiveActivityMan_UpdateLiveActivity_Start",
            "LiveActivityMan_UpdateLiveActivity_Fail"
        ])
    }

    /// After iOS evicts the app a Lock Screen tap runs in a fresh process where nothing has ensured
    /// an activity, so the manager has to ask the system for this session's. With none to find the
    /// push is dropped and reported, and not remembered: a state recorded here would make the
    /// equality gate swallow the identical retry once an activity is there to take it.
    @Test("Test A Push With No Activity To Find Is Reported And Not Remembered")
    func testAPushWithNoActivityToFindIsReportedAndNotRemembered() {
        let spy = SpyLogService()
        var asked: [String] = []
        let manager = LiveActivityManager(logger: LogManager(services: [spy])) { sessionId in
            asked.append(sessionId)
            return nil
        }

        manager.updateLiveActivity(params: params())

        #expect(asked == ["s1"])
        #expect(spy.trackedEventNames.contains("LiveActivityMan_UpdateLiveActivity_Fail"))
        #expect(manager.lastContentState == nil)
    }

    /// The public entry point logged a Start and then called the private one, which logged another,
    /// so every update counted twice.
    @Test("Test One Update Reports One Start")
    func testOneUpdateReportsOneStart() {
        let (manager, spy) = makeManager()

        manager.updateLiveActivity(params: params())

        #expect(spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count == 1)
    }

    /// A tick that changes nothing is not an attempt. The Start used to be logged above the
    /// no-op guard, so unchanged ticks filled the funnel with Starts nothing ever answered.
    ///
    /// Only a push that reached an activity is remembered, so this one needs a real activity to
    /// reach; the test host is the app and can request one.
    @Test("Test An Unchanged Update Reports Nothing")
    func testAnUnchangedUpdateReportsNothing() async throws {
        let spy = SpyLogService()
        var activity: Activity<WorkoutActivityAttributes>?
        let manager = LiveActivityManager(logger: LogManager(services: [spy])) { _ in activity }
        activity = try Activity.request(
            attributes: WorkoutActivityAttributes(sessionId: "s1", workoutName: "Upper"),
            content: ActivityContent(state: manager.makeContentState(session: params().session, isActive: false, currentExerciseIndex: 0, restEndsAt: nil), staleDate: nil),
            pushType: nil
        )
        defer { Task { await activity?.end(nil, dismissalPolicy: .immediate) } }

        manager.updateLiveActivity(params: params())
        manager.updateLiveActivity(params: params())

        #expect(spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count == 1)
        #expect(!spy.trackedEventNames.contains("LiveActivityMan_UpdateLiveActivity_Fail"))
    }

    /// An intent pushes its loading state straight to ActivityKit, behind the manager's memory of
    /// the last push. The handler's answer to a tap that changed nothing is that same state again,
    /// and the equality gate used to swallow it — leaving the button disabled.
    @Test("Test An Unchanged Update Still Lands While The Activity Is Loading")
    func testAnUnchangedUpdateStillLandsWhileTheActivityIsLoading() async throws {
        let spy = SpyLogService()
        var activity: Activity<WorkoutActivityAttributes>?
        let manager = LiveActivityManager(logger: LogManager(services: [spy])) { _ in activity }
        activity = try Activity.request(
            attributes: WorkoutActivityAttributes(sessionId: "s1", workoutName: "Upper"),
            content: ActivityContent(state: manager.makeContentState(session: params().session, isActive: false, currentExerciseIndex: 0, restEndsAt: nil), staleDate: nil),
            pushType: nil
        )
        defer { Task { await activity?.end(nil, dismissalPolicy: .immediate) } }
        manager.updateLiveActivity(params: params())
        // The push lands on its own task. Applying the loading state before it has landed let
        // the push overwrite it, and the second update then saw nothing to answer.
        #expect(await TestManagers.eventually { activity?.content.state.isActive == true })

        var loading = try #require(manager.lastContentState)
        loading.isProcessingIntent = true
        await activity?.update(ActivityContent(state: loading, staleDate: nil))
        // `content` is refreshed behind the update, not by it, and the gate reads `content`.
        #expect(await TestManagers.eventually { activity?.content.state.isProcessingIntent == true })
        manager.updateLiveActivity(params: params())

        #expect(spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count == 2)
    }

    /// The rest push used to be the odd one out: it rebuilt the state memberwise inside its own
    /// task, skipped the equality gate and logged nothing. It is now the same door as every other
    /// push, so an unchanged rest is quiet and a changed one is a Start that reaches the activity.
    @Test("Test A Rest Update Is Gated And Logged Like Any Other Push")
    func testARestUpdateIsGatedAndLoggedLikeAnyOtherPush() async throws {
        let spy = SpyLogService()
        var activity: Activity<WorkoutActivityAttributes>?
        let manager = LiveActivityManager(logger: LogManager(services: [spy])) { _ in activity }
        activity = try Activity.request(
            attributes: WorkoutActivityAttributes(sessionId: "s1", workoutName: "Upper"),
            content: ActivityContent(state: manager.makeContentState(session: params().session, isActive: false, currentExerciseIndex: 0, restEndsAt: nil), staleDate: nil),
            pushType: nil
        )
        defer { Task { await activity?.end(nil, dismissalPolicy: .immediate) } }
        manager.updateLiveActivity(params: params())
        let startsAfterFirstPush = spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count

        manager.updateRestAndActive(isActive: true, restEndsAt: nil)
        #expect(spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count == startsAfterFirstPush)

        let restEndsAt = Date().addingTimeInterval(90)
        manager.updateRestAndActive(isActive: true, restEndsAt: restEndsAt)
        #expect(spy.trackedEventNames.filter { $0 == "LiveActivityMan_UpdateLiveActivity_Start" }.count == startsAfterFirstPush + 1)
        #expect(!spy.trackedEventNames.contains("LiveActivityMan_UpdateLiveActivity_Fail"))
        #expect(manager.lastContentState?.restEndsAt == restEndsAt)
    }

    /// With nothing pushed yet there is no exercise to carry over, so the rest push has nothing
    /// to build on and is dropped without an attempt being logged.
    @Test("Test A Rest Update Before Any Push Is Dropped Quietly")
    func testARestUpdateBeforeAnyPushIsDroppedQuietly() {
        let (manager, spy) = makeManager()

        manager.updateRestAndActive(isActive: true, restEndsAt: Date().addingTimeInterval(90))

        #expect(spy.trackedEventNames.isEmpty)
        #expect(manager.lastContentState == nil)
    }

    // MARK: - The content state

    private func set(
        id: String,
        reps: Int,
        weightKg: Double,
        isWarmup: Bool = false,
        completedAt: Date? = nil
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: completedAt,
            dateCreated: Date(timeIntervalSince1970: 1_772_000_000)
        )
    }

    private func exercise(id: String, name: String, index: Int, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(id)",
            name: name,
            trackingMode: .weightReps,
            index: index,
            sets: sets
        )
    }

    /// Two exercises: the first has a set logged a minute ago and one logged just now, the second
    /// opens with a warm-up the activity must not offer as the next target.
    private func twoExerciseSession() -> WorkoutSessionModel {
        let logged = Date(timeIntervalSince1970: 1_772_000_100)
        return WorkoutSessionModel(
            id: "s1",
            authorId: "author-1",
            name: "Upper",
            dateCreated: Date(timeIntervalSince1970: 1_772_000_000),
            exercises: [
                exercise(id: "e1", name: "Bench press", index: 1, sets: [
                    set(id: "set-1", reps: 8, weightKg: 60, completedAt: logged.addingTimeInterval(-60)),
                    set(id: "set-2", reps: 6, weightKg: 65, completedAt: logged),
                    set(id: "set-3", reps: 6, weightKg: 65)
                ]),
                exercise(id: "e2", name: "Incline press", index: 2, sets: [
                    set(id: "set-4", reps: 12, weightKg: 20, isWarmup: true),
                    set(id: "set-5", reps: 10, weightKg: 40)
                ])
            ]
        )
    }

    private func contentState(restEndsAt: Date?) -> WorkoutActivityAttributes.ContentState {
        let (manager, _) = makeManager()
        return manager.makeContentState(
            session: twoExerciseSession(), isActive: true, currentExerciseIndex: 0, restEndsAt: restEndsAt
        )
    }

    /// The unit is the current exercise's own preference, looked up by template id, so a lifter
    /// who logs bench in pounds sees pounds on the Lock Screen rather than a kilogram default.
    @Test("Test The Weight Unit Is The Current Exercises Preference")
    func testTheWeightUnitIsTheCurrentExercisesPreference() {
        let manager = LiveActivityManager(
            logger: LogManager(services: []),
            activityLookup: { _ in nil },
            weightUnit: { $0 == "template-e1" ? .pounds : .kilograms }
        )

        let bench = manager.makeContentState(
            session: twoExerciseSession(), isActive: true, currentExerciseIndex: 0, restEndsAt: nil
        )
        let incline = manager.makeContentState(
            session: twoExerciseSession(), isActive: true, currentExerciseIndex: 1, restEndsAt: nil
        )

        #expect(bench.weightUnit == .pounds)
        #expect(incline.weightUnit == .kilograms)
    }

    /// The rest that follows a logged set is the correction window (spec §4), so that is exactly
    /// when the activity carries the set the buttons would adjust — the most recently completed
    /// one, not the first.
    @Test("Test A Rest In Progress Carries The Set Just Logged")
    func testARestInProgressCarriesTheSetJustLogged() {
        let state = contentState(restEndsAt: Date().addingTimeInterval(60))

        #expect(state.lastLoggedSetId == "set-2")
        #expect(state.lastLoggedReps == 6)
        #expect(state.lastLoggedWeightKg == 65)
    }

    /// A rest inside an exercise stays quiet about the exercise; the rest after its last set leads
    /// into the next one, and the state says so, since the target it carries is already that
    /// exercise's first set.
    @Test("Test A Rest After The Last Set Of An Exercise Leads Into The Next")
    func testARestAfterTheLastSetOfAnExerciseLeadsIntoTheNext() {
        #expect(contentState(restEndsAt: Date().addingTimeInterval(60)).restLeadsToNewExercise == false)

        let logged = Date()
        let session = WorkoutSessionModel(
            id: "s4",
            authorId: "author-1",
            name: "Upper",
            dateCreated: logged,
            exercises: [
                exercise(id: "e1", name: "Bench press", index: 1, sets: [
                    set(id: "set-1", reps: 8, weightKg: 60, completedAt: logged)
                ]),
                exercise(id: "e2", name: "Incline press", index: 2, sets: [
                    set(id: "set-2", reps: 10, weightKg: 40)
                ])
            ]
        )
        let (manager, _) = makeManager()
        let state = manager.makeContentState(
            session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: logged.addingTimeInterval(60)
        )

        #expect(state.restLeadsToNewExercise)
        #expect(state.currentExerciseName == "Incline press")
        #expect(state.lastLoggedSetId == "set-1")
        guard case .resting(_, _, _, let nextExerciseName) = LiveActivityPhase(state: state, now: logged, isStale: false) else {
            Issue.record("expected .resting"); return
        }
        #expect(nextExerciseName == "Incline press")
    }

    /// Rebuilding the state from the rest is what clears the window when the rest ends: there is
    /// no separate bookkeeping to forget.
    @Test("Test No Rest Leaves The Logged Set Empty")
    func testNoRestLeavesTheLoggedSetEmpty() {
        let state = contentState(restEndsAt: nil)

        #expect(state.lastLoggedSetId == nil)
        #expect(state.lastLoggedReps == nil)
        #expect(state.lastLoggedWeightKg == nil)

        let passed = contentState(restEndsAt: Date().addingTimeInterval(-1))
        #expect(passed.lastLoggedSetId == nil)
    }

    // MARK: - Never describing a finished exercise

    /// The state is built from the next exercise with work left when the requested one is
    /// finished, so the rest-end push cannot strand the banner on an exercise with no target.
    @Test("Test A Finished Exercise Index Advances To The Next With Work Left")
    func testAFinishedExerciseIndexAdvancesToTheNextWithWorkLeft() {
        let logged = Date()
        let session = WorkoutSessionModel(
            id: "s2",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: logged,
            exercises: [
                exercise(id: "e1", name: "Bench press", index: 1, sets: [
                    set(id: "set-1", reps: 8, weightKg: 60, completedAt: logged)
                ]),
                exercise(id: "e2", name: "Incline press", index: 2, sets: [
                    set(id: "set-2", reps: 10, weightKg: 40)
                ])
            ]
        )

        #expect(LiveActivityManager.exerciseIndexWithWorkLeft(from: 0, in: session) == 1)
        #expect(LiveActivityManager.exerciseIndexWithWorkLeft(from: 1, in: session) == 1)

        let (manager, _) = makeManager()
        let state = manager.makeContentState(session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: nil)
        #expect(state.currentExerciseIndex == 1)
        #expect(state.currentExerciseName == "Incline press")
        #expect(state.targetSetId == "set-2")
    }

    /// A skipped exercise still has sets. With A skipped and B, C finished the tracker sits on C,
    /// and nothing later has work left, so the search wraps to A rather than stranding the banner
    /// on a finished exercise with no target.
    @Test("Test A Finished Exercise Falls Back To The First With Work Left Anywhere")
    func testAFinishedExerciseFallsBackToTheFirstWithWorkLeftAnywhere() {
        let logged = Date()
        let session = WorkoutSessionModel(
            id: "s4",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: logged,
            exercises: [
                exercise(id: "a", name: "A", index: 1, sets: [
                    set(id: "a-1", reps: 8, weightKg: 60)
                ]),
                exercise(id: "b", name: "B", index: 2, sets: [
                    set(id: "b-1", reps: 10, weightKg: 40, completedAt: logged)
                ]),
                exercise(id: "c", name: "C", index: 3, sets: [
                    set(id: "c-1", reps: 12, weightKg: 20, completedAt: logged)
                ])
            ]
        )

        #expect(LiveActivityManager.exerciseIndexWithWorkLeft(from: 2, in: session) == 0)

        let (manager, _) = makeManager()
        let state = manager.makeContentState(session: session, isActive: true, currentExerciseIndex: 2, restEndsAt: nil)
        #expect(state.currentExerciseIndex == 0)
        #expect(state.currentExerciseName == "A")
        #expect(state.targetSetId == "a-1")
        #expect(state.targetWeightKg == 60)
        #expect(state.targetReps == 8)
    }

    /// When nothing anywhere has work left the requested index stands, and all-sets-complete takes
    /// over from there.
    @Test("Test A Finished Last Exercise Keeps Its Index")
    func testAFinishedLastExerciseKeepsItsIndex() {
        let logged = Date()
        let session = WorkoutSessionModel(
            id: "s3",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: logged,
            exercises: [
                exercise(id: "e1", name: "Bench press", index: 1, sets: [
                    set(id: "set-1", reps: 8, weightKg: 60, completedAt: logged)
                ])
            ]
        )

        #expect(LiveActivityManager.exerciseIndexWithWorkLeft(from: 0, in: session) == 0)
    }

    // MARK: - Paired sets and the position

    /// After the left half of a pair the user is still on that set, so the completed count the
    /// position is built from leaves it out; once both halves are done it counts as one.
    @Test("Test A Half Done Pair Does Not Count As A Completed Set")
    func testAHalfDonePairDoesNotCountAsACompletedSet() {
        let logged = Date()
        let left = WorkoutSetModel(
            id: "s1-left", authorId: "author-1", index: 1, reps: 8, weightKg: 20,
            side: .left, isWarmup: false, completedAt: logged, dateCreated: logged
        )
        var right = WorkoutSetModel(
            id: "s1-right", authorId: "author-1", index: 1, reps: 8, weightKg: 20,
            side: .right, isWarmup: false, completedAt: nil, dateCreated: logged
        )
        let second = WorkoutSetModel(
            id: "s2", authorId: "author-1", index: 2, reps: 8, weightKg: 20,
            side: nil, isWarmup: false, completedAt: nil, dateCreated: logged
        )

        #expect([left, right, second].fullyCompletedPairedSetCount == 0)

        right.completedAt = logged
        #expect([left, right, second].fullyCompletedPairedSetCount == 1)
    }

    /// With every other set done and the left half of the last pair logged, the workout is not
    /// over: the whole-workout totals used to read the lone left row as a finished set, so the
    /// banner showed "All sets complete" and offered Finish with the right row still to do.
    @Test("Test A Half Done Last Pair Is Not All Sets Done")
    func testAHalfDoneLastPairIsNotAllSetsDone() {
        let logged = Date()
        func row(_ id: String, index: Int, side: SetSide, done: Bool) -> WorkoutSetModel {
            WorkoutSetModel(
                id: id, authorId: "author-1", index: index, reps: 8, weightKg: 20,
                side: side, isWarmup: false, completedAt: done ? logged : nil, dateCreated: logged
            )
        }
        let session = WorkoutSessionModel(
            id: "s4",
            authorId: "author-1",
            name: "Arms",
            dateCreated: logged,
            exercises: [
                exercise(id: "e1", name: "Single-arm row", index: 1, sets: [
                    row("1L", index: 1, side: .left, done: true),
                    row("1R", index: 2, side: .right, done: true),
                    row("2L", index: 3, side: .left, done: true),
                    row("2R", index: 4, side: .right, done: false)
                ])
            ]
        )

        let (manager, _) = makeManager()
        let state = manager.makeContentState(session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: nil)

        #expect(state.targetSetId == "2R")
        #expect(state.isAllSetsComplete == false)
        #expect(state.progress < 1)
        guard case .ready(_, let position) = LiveActivityPhase(state: state, now: logged, isStale: false) else {
            Issue.record("expected .ready, got \(LiveActivityPhase(state: state, now: logged, isStale: false))")
            return
        }
        #expect(position == SetPosition(index: 2, total: 2))
    }

    /// Two warm-ups then four working sets read as "Warmup 1 of 2" ... "Set 1 of 4", never as six.
    @Test("Test The Position Counts Warm Ups And Working Sets Separately")
    func testThePositionCountsWarmUpsAndWorkingSetsSeparately() {
        let logged = Date()
        func row(_ id: String, index: Int, warmup: Bool, done: Bool) -> WorkoutSetModel {
            WorkoutSetModel(
                id: id, authorId: "author-1", index: index, reps: 8, weightKg: 20,
                isWarmup: warmup, completedAt: done ? logged : nil, dateCreated: logged
            )
        }
        func sets(warmupsDone: Int, workingDone: Int) -> [WorkoutSetModel] {
            (1...2).map { row("w\($0)", index: $0, warmup: true, done: $0 <= warmupsDone) }
                + (1...4).map { row("s\($0)", index: $0 + 2, warmup: false, done: $0 <= workingDone) }
        }

        #expect(LiveActivityManager.exercisePosition(in: sets(warmupsDone: 0, workingDone: 0))
            == Position(completed: 0, total: 2, isWarmup: true))
        #expect(LiveActivityManager.exercisePosition(in: sets(warmupsDone: 1, workingDone: 0))
            == Position(completed: 1, total: 2, isWarmup: true))
        #expect(LiveActivityManager.exercisePosition(in: sets(warmupsDone: 2, workingDone: 0))
            == Position(completed: 0, total: 4, isWarmup: false))
        #expect(LiveActivityManager.exercisePosition(in: sets(warmupsDone: 2, workingDone: 3))
            == Position(completed: 3, total: 4, isWarmup: false))
        // Finished: the working sets are all counted, which is what the exercise-done phase needs.
        #expect(LiveActivityManager.exercisePosition(in: sets(warmupsDone: 2, workingDone: 4))
            == Position(completed: 4, total: 4, isWarmup: false))
    }

    /// The tracker does not order the two sides, so a right row ticked first is just as half done.
    @Test("Test A Right Row Ticked Before Its Left Partner Does Not Count Either")
    func testARightRowTickedBeforeItsLeftPartnerDoesNotCountEither() {
        let logged = Date()
        var left = WorkoutSetModel(
            id: "s1-left", authorId: "author-1", index: 1, reps: 8, weightKg: 20,
            side: .left, isWarmup: false, completedAt: nil, dateCreated: logged
        )
        let right = WorkoutSetModel(
            id: "s1-right", authorId: "author-1", index: 1, reps: 8, weightKg: 20,
            side: .right, isWarmup: false, completedAt: logged, dateCreated: logged
        )

        #expect([left, right].fullyCompletedPairedSetCount == 0)

        left.completedAt = logged
        #expect([left, right].fullyCompletedPairedSetCount == 1)
    }
}

}

#endif
