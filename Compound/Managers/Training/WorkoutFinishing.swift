//
//  WorkoutFinishing.swift
//  Compound
//
//  The one way a workout is finished, whoever asks: the tracker's Finish button and the Live
//  Activity's both come through here. The handler used to keep its own copy of the tracker's
//  finish and had drifted — no rest-day pre-completion, no gym-profile reset, and a failed save
//  after HealthKit had already been ended (docs/reviews/live-activity-review.md F4).
//
//  The caller has already stamped `endedAt` on the session. The tracker keeps its retry loop and
//  toasts around this; the handler has no screen to tell, so it takes the first answer.
//

import Foundation

/// What one attempt at the save came back with.
enum WorkoutSaveOutcome: Equatable {
    case saved
    /// The same request could plausibly succeed later — worth another go.
    case failedTransiently
    /// The request itself was rejected, and will be rejected identically every time.
    case failedPermanently
}

extension WorkoutSessionModel {
    /// Sent once a finished workout is stored, by whichever path stored it: this function or the
    /// tracker's retry. The core action in analytics, so the name is plain rather than screen-scoped.
    static let finishedEventName = "Workout_Finished"

    var finishedEventParameters: [String: Any] {
        [
            "exercise_count": exercises.count,
            "completed_set_count": exercises.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil }.count },
            "duration_minutes": Int((activeDuration ?? 0) / 60),
            "from_template": workoutTemplateId != nil,
            "from_plan": mesocycleId != nil,
            "is_rest_day": isRestDay
        ]
    }
}

/// One attempt at storing a finished workout, classified for the caller's retry.
@MainActor
func saveFinishedWorkout(
    _ session: WorkoutSessionModel,
    sessions: WorkoutSessionManager,
    logger: LogManager
) async -> WorkoutSaveOutcome {
    do {
        try await sessions.endWorkoutSession(session)
        logger.trackEvent(eventName: WorkoutSessionModel.finishedEventName, parameters: session.finishedEventParameters)
        return .saved
    } catch {
        logger.trackEvent(
            eventName: "finish_workout_save_error",
            parameters: [
                "error": error.localizedDescription,
                "is_transient": error.isTransientWriteFailure
            ],
            type: .severe
        )
        return error.isTransientWriteFailure ? .failedTransiently : .failedPermanently
    }
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// The managers finishing a workout touches. The streak and Strava are optional so a test can
/// finish without them.
@MainActor
struct WorkoutFinishManagers {
    let sessions: WorkoutSessionManager
    let hkWorkout: HKWorkoutManager
    let liveActivity: any LiveActivityUpdating
    let gymProfiles: GymProfileManager
    let mesocycles: MesocycleManager
    let users: UserManager
    var macrocycles: MacrocycleManager?
    var streak: StreakManager?
    var strava: StravaManager?
    let logger: LogManager
}

/// Ends HealthKit, saves the session, takes down the Live Activity, then runs the side effects of
/// having finished. Answers how the save went so the tracker can retry it.
///
/// The activity is torn down on the first answer rather than the last: waiting for a whole retry
/// schedule would leave the Dynamic Island claiming a workout was under way for half a minute
/// after the user finished it. The side effects are each independent of the save and of each
/// other — a failed streak write must not skip the Strava upload.
@MainActor
func finishWorkout(_ session: WorkoutSessionModel, using managers: WorkoutFinishManagers) async -> WorkoutSaveOutcome {
    let logger = managers.logger
    managers.gymProfiles.activeWorkoutGymProfile = nil
    SharedWorkoutStorage.clearHKStartedSessionId()
    managers.hkWorkout.endWorkout()

    let outcome = await saveFinishedWorkout(session, sessions: managers.sessions, logger: logger)
    managers.liveActivity.endLiveActivity(session: session, isCompleted: outcome == .saved)

    if let streak = managers.streak {
        do {
            _ = try await streak.addStreakEvent()
            // Followers cannot read the author's streak, so it rides on the session they can
            // read. A second write rather than stamping before the save: the save goes first so
            // it is never held up by the streak, and a session that did not save has nothing to
            // stamp. The stamp is best-effort — a session without it renders as before.
            if outcome == .saved, let count = streak.currentStreakData.currentStreak {
                var stamped = session
                stamped.streakCount = count
                try await managers.sessions.saveWorkoutSession(stamped)
            }
        } catch {
            logger.trackEvent(eventName: "finish_workout_streak_error", parameters: ["error": error.localizedDescription], type: .warning)
        }
    }
    await preCompleteConsecutiveRestDays(
        after: session,
        in: managers.mesocycles.activeMesocycle(for: managers.users.currentUser),
        sessions: managers.sessions
    )
    // Only a saved workout: one that failed to save would be on Strava and nowhere in Compound.
    if outcome == .saved, let strava = managers.strava, strava.isConnected {
        do {
            try await strava.uploadWorkout(session)
        } catch {
            logger.trackEvent(eventName: "strava_upload_error", parameters: ["error": error.localizedDescription], type: .warning)
        }
    }
    let sessionsIncludingThis = managers.sessions.workoutSessions.filter { $0.id != session.id } + [session]
    if outcome == .saved {
        await advanceMacrocycle(using: managers, sessions: sessionsIncludingThis)
        refreshWidgetSnapshot(
            users: managers.users,
            mesocycles: managers.mesocycles,
            macrocycles: managers.macrocycles,
            sessions: sessionsIncludingThis,
            streak: managers.streak?.currentStreakData.currentStreak
        )
        recordFinishedSessionForReviewPrompt(session)
        if let user = managers.users.currentUser {
            requestReviewIfEarned(.workoutFinished(
                sessionsThisWeek: CircleWeek.sessionCount(of: user.userId, inWeekOf: .now, sessions: sessionsIncludingThis),
                weeklyGoal: CircleWeek.goal(for: user)
            ))
        }
    }
    return outcome
}

/// A workout that finishes the block's last open slot moves the plan on. Best-effort: the
/// session is saved either way, and the next finish or skip tries again.
@MainActor
private func advanceMacrocycle(using managers: WorkoutFinishManagers, sessions: [WorkoutSessionModel]) async {
    guard let macrocycles = managers.macrocycles else { return }
    do {
        try await advanceMacrocycleIfMesocycleComplete(macrocycles: macrocycles, mesocycles: managers.mesocycles, users: managers.users, sessions: sessions)
    } catch {
        managers.logger.trackEvent(eventName: "finish_workout_plan_advance_error", parameters: ["error": error.localizedDescription], type: .warning)
    }
}

#endif

/// Pre-creates a completed rest-day session for each rest day that follows the finished workout
/// in its mesocycle, so the calendar shows them done rather than waiting on the user to tap through.
/// First removes any rest day logged for today: the user trained through it, and the schedule
/// then shows it skipped rather than taken.
@MainActor
func preCompleteConsecutiveRestDays(
    after session: WorkoutSessionModel,
    in mesocycle: Mesocycle?,
    sessions: WorkoutSessionManager
) async {
    guard let mesocycle, mesocycle.id == session.mesocycleId,
          let templateId = session.workoutTemplateId else { return }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    for rest in sessions.workoutSessions where rest.isRestDay && rest.mesocycleId == mesocycle.id
        && calendar.isDate(rest.dateCreated, inSameDayAs: today) {
        try? await sessions.deleteWorkoutSession(id: rest.id)
    }

    let restTemplates = consecutiveRestTemplates(after: templateId, in: mesocycle)
    guard !restTemplates.isEmpty else { return }
    let existingSessions = sessions.workoutSessions

    for (offset, restTemplate) in restTemplates.enumerated() {
        // Safe: adding days to a valid date never returns nil.
        let restDate = calendar.date(byAdding: .day, value: offset + 1, to: today)!

        let alreadyExists = existingSessions.contains { existing in
            existing.isRestDay &&
            existing.workoutTemplateId == restTemplate.id &&
            calendar.isDate(existing.dateCreated, inSameDayAs: restDate)
        }
        guard !alreadyExists else { continue }

        let restSession = WorkoutSessionModel(
            authorId: session.authorId,
            name: restTemplate.name,
            workoutTemplateId: restTemplate.id,
            mesocycleId: mesocycle.id,
            dateCreated: restDate,
            endedAt: restDate,
            exercises: [],
            isRestDay: true
        )
        try? await sessions.saveWorkoutSession(restSession)
    }
}

private func consecutiveRestTemplates(after templateId: String, in mesocycle: Mesocycle) -> [WorkoutTemplateModel] {
    let templates = mesocycle.workoutTemplates
    guard let idx = templates.firstIndex(where: { $0.id == templateId }) else { return [] }
    var rests: [WorkoutTemplateModel] = []
    var next = idx + 1
    while next < templates.count, templates[next].exercises.isEmpty {
        rests.append(templates[next])
        next += 1
    }
    return rests
}
