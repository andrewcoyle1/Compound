//
//  WorkoutTrackerAnnouncementTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What the tracker tells VoiceOver as the screen changes under it (a11y.md S1): a set logged, a
/// rest run out whatever the sound and vibration settings, and the card moving on. The view
/// reports the changes; these drive the presenter the way it does.
@MainActor
struct WorkoutTrackerAnnouncementTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Two exercises of two 60 kg × 8 sets, no rests, so a log moves nothing but the button.
    private func makeScreen() throws -> (presenter: WorkoutTrackerPresenter, interactor: WorkoutTrackerInteractorDouble) {
        let exercises = ["bench", "row"].enumerated().map { offset, id in
            WorkoutExerciseModel(
                id: id, authorId: "author-1", templateId: "template-\(id)", name: id == "bench" ? "Bench Press" : "Barbell Row",
                trackingMode: .weightReps, index: offset + 1,
                sets: (1...2).map {
                    WorkoutSetModel(id: "\(id)-\($0)", authorId: "author-1", index: $0, reps: 8, weightKg: 60, isWarmup: false, dateCreated: start)
                }
            )
        }
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.useRestTimers = false
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Pull Day", dateCreated: start, exercises: exercises
        )
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble(), saveRetryBackoff: .testImmediate)
        return (presenter, interactor)
    }

    /// Logs as the view sees it: the mark before and after.
    private func log(_ setId: String, in exerciseId: String, on presenter: WorkoutTrackerPresenter) {
        let before = presenter.latestLogMark
        presenter.logSet(setId, in: exerciseId)
        presenter.onLatestLogChanged(from: before, to: presenter.latestLogMark)
    }

    @Test func aLoggedSetIsAnnouncedWithItsFiguresInWords() throws {
        let (presenter, _) = try makeScreen()
        let spy = TrackerAnnouncementSpy()

        spy.listen { log("bench-1", in: "bench", on: presenter) }

        #expect(spy.texts.count == 1)
        let text = try #require(spy.texts.first)
        #expect(text.hasPrefix("Set 1 logged"), "\(text)")
        #expect(text.contains("60") && text.contains("8"), "\(text)")
        // Units in words, not "kg" read letter by letter.
        #expect(!text.contains("kg"), "\(text)")
    }

    /// Undo makes an earlier set the latest. That is not a log, and says nothing.
    @Test func undoingALogIsNotAnnouncedAsOne() throws {
        let (presenter, _) = try makeScreen()
        let spy = TrackerAnnouncementSpy()
        spy.listen { log("bench-1", in: "bench", on: presenter) }
        // A later log, then un-logged.
        presenter.workoutSession.exercises[0].sets[1].completedAt = Date()
        let afterSecond = presenter.latestLogMark

        spy.listen {
            presenter.unlog("bench-2", in: "bench")
            presenter.onLatestLogChanged(from: afterSecond, to: presenter.latestLogMark)
        }

        #expect(spy.texts.count == 1)
    }

    @Test func aRestRunningOutIsAnnouncedWithSoundAndVibrationOff() throws {
        let (presenter, interactor) = try makeScreen()
        interactor.workoutSettings.restTimerPlaySound = false
        interactor.workoutSettings.restTimerVibrate = false
        let spy = TrackerAnnouncementSpy()

        spy.listen { presenter.announceRestOver() }

        #expect(spy.announcements == [TrackerAnnouncement(text: "Rest over", priority: .high)])
    }

    /// The screen's listener hears the rest's owner. Other suites may end rests at the same time,
    /// so this asks only that ours was heard.
    @Test func theRestOverListenerAnnouncesTheOwnersNotification() async throws {
        let (presenter, _) = try makeScreen()
        let spy = TrackerAnnouncementSpy()
        let listener = spy.listen { Task { await presenter.observeRestOverAnnouncements() } }
        defer { listener.cancel() }
        for _ in 0..<10 { await Task.yield() }

        NotificationCenter.default.post(name: Constants.workoutRestDidComplete, object: nil)
        for _ in 0..<50 where spy.texts.isEmpty { await Task.yield() }

        #expect(spy.texts.contains("Rest over"))
    }

    /// Queued behind the log it follows, so neither cuts the other off.
    @Test func theCardMovingOnIsAnnouncedAfterWhatIsBeingRead() throws {
        let (presenter, _) = try makeScreen()
        let spy = TrackerAnnouncementSpy()

        spy.listen {
            let before = presenter.currentExercise?.id
            presenter.onExerciseSelected("row")
            presenter.onCurrentExerciseChanged(from: before, to: presenter.currentExercise?.id)
        }

        #expect(spy.announcements == [TrackerAnnouncement(text: "Now: Barbell Row", priority: .low)])
    }

    @Test func theSameExerciseIsNotAnnouncedAgain() throws {
        let (presenter, _) = try makeScreen()
        let spy = TrackerAnnouncementSpy()

        spy.listen { presenter.onCurrentExerciseChanged(from: "bench", to: "bench") }

        #expect(spy.texts.isEmpty)
    }
}
