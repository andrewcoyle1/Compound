//
//  HKWorkoutDoubles.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Foundation
@testable import DialedIn

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

/// Records what `HKWorkoutManager` asks of the Live Activity.
///
/// The real `LiveActivityManager` cannot start an `Activity` in a test process, so the only way to
/// see what the manager decided is to stand in for the updater it talks to.
@MainActor
final class LiveActivityUpdaterSpy: LiveActivityUpdating {

    struct RestAndActive: Equatable {
        let isActive: Bool
        let restEndsAt: Date?
    }

    private(set) var ensured: [String] = []
    private(set) var fullUpdates: [LiveActivityUpdateParams] = []
    private(set) var restAndActiveUpdates: [RestAndActive] = []
    private(set) var ended: [String] = []

    func ensureLiveActivity(
        session: WorkoutSessionModel,
        isActive: Bool,
        currentExerciseIndex: Int,
        restEndsAt: Date?
    ) {
        ensured.append(session.id)
    }

    func updateLiveActivity(params: LiveActivityUpdateParams) {
        fullUpdates.append(params)
    }

    func updateRestAndActive(isActive: Bool, restEndsAt: Date?) {
        restAndActiveUpdates.append(RestAndActive(isActive: isActive, restEndsAt: restEndsAt))
    }

    func endLiveActivity(session: WorkoutSessionModel, isCompleted: Bool) {
        ended.append(session.id)
    }

    /// Whether an activity is on screen; off by default, as with Live Activities turned off.
    var isShowingLiveActivity = false
    var restOverText: String? = "Next: Bench Press, 60 kg × 8"
    /// `isActive` of each `announceRestOver` call.
    private(set) var restOverAnnouncements: [Bool] = []

    func restOverMessage(session: WorkoutSessionModel, currentExerciseIndex: Int) -> String? {
        restOverText
    }

    func announceRestOver(isActive: Bool) {
        restOverAnnouncements.append(isActive)
    }
}

/// Records the rest-over notification the manager schedules and withdraws, in order, instead of
/// asking the test process for notification permission.
@MainActor
final class RestOverNotifierSpy: RestOverNotifying {

    enum Call: Equatable {
        case schedule(date: Date, body: String?, sound: Bool)
        case cancel
    }

    private(set) var calls: [Call] = []

    func scheduleRestOverNotification(at date: Date, body: String?, sound: Bool) async {
        calls.append(.schedule(date: date, body: body, sound: sound))
    }

    func cancelRestOverNotification() {
        calls.append(.cancel)
    }
}

/// Counts `Constants.workoutRestDidComplete` posts from one manager.
///
/// The manager announces a finished rest to whichever screen is listening rather than calling it,
/// so the post is the only observable difference between a rest that ran out and one that was
/// cancelled. Scoped to the manager under test because the centre is shared with every suite the
/// runner has going at once, and another suite ending its own rest would otherwise be counted here.
/// The count is behind a lock because the notification can be delivered from any queue.
final class RestCompletionSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var posts = 0
    private var token: NSObjectProtocol?

    var count: Int {
        lock.withLock { posts }
    }

    init(_ manager: HKWorkoutManager) {
        token = NotificationCenter.default.addObserver(
            forName: Constants.workoutRestDidComplete,
            object: manager,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.withLock { self.posts += 1 }
        }
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

#endif
