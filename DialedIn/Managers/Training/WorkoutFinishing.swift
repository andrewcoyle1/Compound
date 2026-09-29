//
//  WorkoutFinishing.swift
//  DialedIn
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

/// One attempt at storing a finished workout, classified for the caller's retry.
@MainActor
func saveFinishedWorkout(
    _ session: WorkoutSessionModel,
    sessions: WorkoutSessionManager,
    logger: LogManager
) async -> WorkoutSaveOutcome {
    do {
        try await sessions.endWorkoutSession(session)
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
    let programs: TrainingProgramManager
    let users: UserManager
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
        in: managers.programs.activeProgram(for: managers.users.currentUser),
        sessions: managers.sessions
    )
    if let strava = managers.strava, strava.isConnected {
        do {
            try await strava.uploadWorkout(session)
        } catch {
            logger.trackEvent(eventName: "strava_upload_error", parameters: ["error": error.localizedDescription], type: .warning)
        }
    }
    if outcome == .saved {
        refreshWidgetSnapshot(
            users: managers.users,
            programs: managers.programs,
            sessions: managers.sessions.workoutSessions.filter { $0.id != session.id } + [session],
            streak: managers.streak?.currentStreakData.currentStreak
        )
        recordFinishedSessionForReviewPrompt(session)
    }
    return outcome
}

#endif

/// Pre-creates a completed rest-day session for each rest day that follows the finished workout
/// in its program, so the calendar shows them done rather than waiting on the user to tap through.
@MainActor
func preCompleteConsecutiveRestDays(
    after session: WorkoutSessionModel,
    in program: TrainingProgram?,
    sessions: WorkoutSessionManager
) async {
    guard let program, program.id == session.trainingProgramId,
          let templateId = session.workoutTemplateId else { return }

    let restTemplates = consecutiveRestTemplates(after: templateId, in: program)
    guard !restTemplates.isEmpty else { return }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
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
            trainingProgramId: program.id,
            dateCreated: restDate,
            endedAt: restDate,
            exercises: [],
            isRestDay: true
        )
        try? await sessions.saveWorkoutSession(restSession)
    }
}

private func consecutiveRestTemplates(after templateId: String, in program: TrainingProgram) -> [WorkoutTemplateModel] {
    let templates = program.workoutTemplates
    guard let idx = templates.firstIndex(where: { $0.id == templateId }) else { return [] }
    var rests: [WorkoutTemplateModel] = []
    var next = idx + 1
    while next < templates.count, templates[next].exercises.isEmpty {
        rests.append(templates[next])
        next += 1
    }
    return rests
}
