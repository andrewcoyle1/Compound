//
//  WorkoutTrackerRestFeedbackTests.swift
//  CompoundUnitTests
//
//  Split out of WorkoutTrackerPresenterTests.swift, which exceeded the 750-line file and
//  500-line type-body limits.
//

import Testing
import Foundation
import SwiftUI
import HealthKit
@testable import Compound

/// What the tracker does around a rest, and where it looks for the figures it shows beside the
/// current set.
///
/// Both are settings-dependent and both defaults matter: `previousWorkoutReference` defaults to
/// `.sameWorkout` — stored as `"anyWorkout"`, the unfiltered template lookup every user has today
/// — and the two rest-timer announcements default to on, so a rest ending is announced unless the
/// user says otherwise.
@MainActor
struct WorkoutTrackerRestFeedbackTests {

    private struct Screen {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
        let router: WorkoutTrackerRouterDouble
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private func set(
        _ index: Int,
        reps: Int? = 8,
        weightKg: Double? = 80,
        isWarmup: Bool = false,
        done: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(isWarmup ? "w" : "x")",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: done ? start : nil,
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
            // A set's id is rebuilt to carry its exercise, so two exercises never share one.
            sets: sets.map { original in
                WorkoutSetModel(
                    id: "\(id)-\(original.id)",
                    authorId: original.authorId,
                    index: original.index,
                    reps: original.reps,
                    weightKg: original.weightKg,
                    isWarmup: original.isWarmup,
                    completedAt: original.completedAt,
                    dateCreated: original.dateCreated
                )
            }
        )
    }

    private func session(
        exercises: [WorkoutExerciseModel],
        templateId: String? = nil,
        mesocycleId: String? = nil
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: templateId,
            mesocycleId: mesocycleId,
            dateCreated: start,
            exercises: exercises
        )
    }

    /// A finished session the previous-values lookup can find. Its exercises carry the session's
    /// id so a test can say which session a figure came from.
    private func completed(
        id: String,
        templateId: String?,
        mesocycleId: String?,
        endedAt: Date,
        exerciseTemplateIds: [String] = ["template-e1"]
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: templateId,
            mesocycleId: mesocycleId,
            dateCreated: start,
            endedAt: endedAt,
            exercises: exerciseTemplateIds.map { exerciseTemplateId in
                WorkoutExerciseModel(
                    id: "\(id)-\(exerciseTemplateId)",
                    authorId: "author-1",
                    templateId: exerciseTemplateId,
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: []
                )
            }
        )
    }

    /// Builds the screen the way the app does: the presenter reads the session the interactor
    /// already holds.
    private func makeScreen(
        exercises: [WorkoutExerciseModel],
        settings: (inout WorkoutSettings) -> Void = { _ in },
        templateId: String? = nil,
        mesocycleId: String? = nil
    ) throws -> Screen {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = session(exercises: exercises, templateId: templateId, mesocycleId: mesocycleId)
        settings(&interactor.workoutSettings)
        let router = WorkoutTrackerRouterDouble()
        return Screen(
            presenter: try WorkoutTrackerPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Previous values

    /// A freehand workout has no template to compare against, so the column falls back to the
    /// exercise's own history rather than showing nothing.
    @Test("Test A Workout Without A Template Falls Back To The Exercises Own History")
    func testAWorkoutWithoutATemplateFallsBackToTheExercisesOwnHistory() async throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        screen.interactor.completedSessions = [
            completed(id: "elsewhere", templateId: "other-template", mesocycleId: nil, endedAt: start)
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.presenter.previousExercises["template-e1"]?.id == "elsewhere-template-e1")
    }

    @Test("Test A Workout From A Template Loads What Was Done Last Time")
    func testAWorkoutFromATemplateLoadsWhatWasDoneLastTime() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            templateId: "template-1"
        )
        screen.interactor.completedSessions = [
            completed(id: "last-time", templateId: "template-1", mesocycleId: nil, endedAt: start)
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.presenter.previousExercises["template-e1"]?.id == "last-time-template-e1")
    }

    /// The default, stored as `"anyWorkout"` for every existing user. This workout's own history,
    /// unfiltered by mesocycle — so the more recent freehand run of the same template wins.
    @Test("Test Same-Workout Reference Searches Every Program")
    func testSameWorkoutReferenceSearchesEveryMesocycle() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            templateId: "template-1",
            mesocycleId: "program-1"
        )
        #expect(screen.interactor.workoutSettings.previousWorkoutReference == .sameWorkout)
        screen.interactor.completedSessions = [
            completed(id: "old-in-program", templateId: "template-1", mesocycleId: "program-1", endedAt: start),
            completed(id: "recent-freehand", templateId: "template-1", mesocycleId: nil, endedAt: start.addingTimeInterval(60))
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.interactor.lastCompletedSessionLookups == [nil])
        #expect(screen.presenter.previousExercises["template-e1"]?.id == "recent-freehand-template-e1")
    }

    /// Turned on, the same lookup skips the more recent session logged outside the mesocycle and
    /// reaches back to the last one done within it.
    @Test("Test In-Program Reference Skips Sessions From Outside The Program")
    func testInMesocycleReferenceSkipsSessionsFromOutsideTheMesocycle() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.previousWorkoutReference = .workoutsInMesocycle },
            templateId: "template-1",
            mesocycleId: "program-1"
        )
        screen.interactor.completedSessions = [
            completed(id: "old-in-program", templateId: "template-1", mesocycleId: "program-1", endedAt: start),
            completed(id: "recent-freehand", templateId: "template-1", mesocycleId: nil, endedAt: start.addingTimeInterval(60)),
            completed(id: "other-program", templateId: "template-1", mesocycleId: "program-2", endedAt: start.addingTimeInterval(120))
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.interactor.lastCompletedSessionLookups == ["program-1"])
        #expect(screen.presenter.previousExercises["template-e1"]?.id == "old-in-program-template-e1")
    }

    /// A one-off workout is in no mesocycle, so there is no mesocycle for it to be "within". Filtering
    /// on nothing would blank the previous column instead of narrowing it.
    @Test("Test In-Program Reference Does Not Filter A Workout Outside Any Program")
    func testInMesocycleReferenceDoesNotFilterAWorkoutOutsideAnyMesocycle() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.previousWorkoutReference = .workoutsInMesocycle },
            templateId: "template-1"
        )
        screen.interactor.completedSessions = [
            completed(id: "in-program", templateId: "template-1", mesocycleId: "program-1", endedAt: start)
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.interactor.lastCompletedSessionLookups == [nil])
        #expect(screen.presenter.previousExercises["template-e1"]?.id == "in-program-template-e1")
    }

    /// The fallback the whole rework is for: a template that has never held this exercise still
    /// shows the last time the user performed it anywhere.
    @Test("Test An Exercise New To This Workout Still Shows Its Own History")
    func testAnExerciseNewToThisWorkoutStillShowsItsOwnHistory() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            templateId: "template-1"
        )
        screen.interactor.completedSessions = [
            completed(
                id: "this-workout",
                templateId: "template-1",
                mesocycleId: nil,
                endedAt: start.addingTimeInterval(60),
                exerciseTemplateIds: ["template-e2"]
            ),
            completed(id: "elsewhere", templateId: "other-template", mesocycleId: nil, endedAt: start)
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.presenter.previousExercises["template-e1"]?.id == "elsewhere-template-e1")
    }

    /// The new scope. The template is not consulted, so the most recent time the exercise was
    /// performed wins wherever it happened.
    @Test("Test Any-Exercise Reference Reads The Most Recent Performance Anywhere")
    func testAnyExerciseReferenceReadsTheMostRecentPerformanceAnywhere() async throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.previousWorkoutReference = .anyExercise },
            templateId: "template-1"
        )
        screen.interactor.completedSessions = [
            completed(id: "this-workout", templateId: "template-1", mesocycleId: nil, endedAt: start),
            completed(id: "elsewhere", templateId: "other-template", mesocycleId: nil, endedAt: start.addingTimeInterval(60))
        ]

        screen.presenter.loadPreviousWorkoutSession()
        await settle()

        #expect(screen.interactor.lastCompletedSessionLookups.isEmpty)
        #expect(screen.presenter.previousExercises["template-e1"]?.id == "elsewhere-template-e1")
    }

    // MARK: - Announcing the end of a rest

    /// Both on by default, so a rest ending is announced to every existing user in both ways.
    @Test("Test A Finished Rest Is Announced By Sound And Vibration")
    func testAFinishedRestIsAnnouncedBySoundAndVibration() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])
        #expect(screen.interactor.workoutSettings.restTimerPlaySound)
        #expect(screen.interactor.workoutSettings.restTimerVibrate)

        screen.presenter.announceRestCompletion()

        #expect(screen.interactor.playedSounds == [.restComplete])
        #expect(screen.interactor.playedHaptics.count == 1)
        // Not the `.success` a logged set plays, so the two can be told apart.
        let isWarning: Bool
        if case .warning? = screen.interactor.playedHaptics.first { isWarning = true } else { isWarning = false }
        #expect(isWarning)
    }

    /// The two are separate settings because a gym is a place where one is wanted without the
    /// other. Turning the sound off must leave the vibration alone.
    @Test("Test A Finished Rest Only Vibrates When The Sound Is Off")
    func testAFinishedRestOnlyVibratesWhenTheSoundIsOff() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.restTimerPlaySound = false }
        )

        screen.presenter.announceRestCompletion()

        #expect(screen.interactor.playedSounds.isEmpty)
        #expect(screen.interactor.playedHaptics.count == 1)
    }

    @Test("Test A Finished Rest Only Sounds When The Vibration Is Off")
    func testAFinishedRestOnlySoundsWhenTheVibrationIsOff() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.restTimerVibrate = false }
        )

        screen.presenter.announceRestCompletion()

        #expect(screen.interactor.playedSounds == [.restComplete])
        #expect(screen.interactor.playedHaptics.isEmpty)
    }

    /// With both off the rest ends in silence, which is the whole point of turning them off.
    @Test("Test A Finished Rest Says Nothing When Both Are Off")
    func testAFinishedRestSaysNothingWhenBothAreOff() throws {
        let screen = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: {
                $0.restTimerPlaySound = false
                $0.restTimerVibrate = false
            }
        )

        screen.presenter.announceRestCompletion()

        #expect(screen.interactor.playedSounds.isEmpty)
        #expect(screen.interactor.playedHaptics.isEmpty)
    }

    /// The sound has to be loaded before it is wanted, so starting a rest loads it — but only when
    /// there is a sound to play at the end of it.
    @Test("Test Starting A Rest Loads The Sound Only When It Will Be Played")
    func testStartingARestLoadsTheSoundOnlyWhenItWillBePlayed() throws {
        let screen = try makeScreen(exercises: [exercise(id: "e1", index: 1, sets: [set(1)])])

        screen.presenter.startRestTimer(durationSeconds: 60)
        #expect(screen.interactor.preparedSounds == [.restComplete])

        let silent = try makeScreen(
            exercises: [exercise(id: "e1", index: 1, sets: [set(1)])],
            settings: { $0.restTimerPlaySound = false }
        )

        silent.presenter.startRestTimer(durationSeconds: 60)
        #expect(silent.interactor.preparedSounds.isEmpty)
    }
}
