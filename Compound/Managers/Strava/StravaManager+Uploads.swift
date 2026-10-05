//
//  StravaManager+Uploads.swift
//  Compound
//
//  Sending finished workouts to Strava through a queue. A workout is queued when it is finished
//  and when the athlete asks for past workouts to go up; the queue is sent then, at sign-in and
//  after each later finish, and an entry leaves it only once Strava has the workout or never
//  will. Kept per account in `UserDefaults`, as a sync engine keeps its pending writes.
//

import Foundation

extension StravaManager {

    /// What sending one session came to.
    enum UploadOutcome: Equatable {
        /// Strava made the activity.
        case linked(activityId: Int)
        /// Nothing Strava can take: no completed set it can place.
        case nothingToSend
        /// Strava had not finished after the wait. Sending again answers the same activity as a
        /// duplicate, so the session stays queued to pick up its id.
        case processing
    }

    // MARK: - Queue

    /// Queues a finished workout and sends the queue. `session` is the one just saved, which the
    /// session manager's copy may not have caught up with yet.
    func queueUpload(_ session: WorkoutSessionModel) async {
        guard isConnected else { return }
        if !pendingSessionIds.contains(session.id) {
            pendingSessionIds.append(session.id)
            savePendingUploads()
        }
        await syncPendingUploads(including: session)
    }

    /// The account's finished workouts that are not on Strava yet and are not queued, oldest first.
    var backfillCandidates: [WorkoutSessionModel] {
        sessions.workoutSessions
            .filter { session in
                session.authorId == userId && session.endedAt != nil && !session.isRestDay
                    && session.deletedAt == nil && session.stravaActivityId == nil
                    && !pendingSessionIds.contains(session.id)
                    && StravaStrengthFile(session: session, library: exercises.allExercises) != nil
            }
            .sorted { $0.dateCreated < $1.dateCreated }
    }

    /// Queues every past workout not on Strava yet, and answers how many. Sending is the caller's
    /// to start: a long backlog runs into Strava's request limit and finishes over later syncs.
    @discardableResult
    func queueBackfill() -> Int {
        let candidates = backfillCandidates.map(\.id)
        pendingSessionIds.append(contentsOf: candidates)
        savePendingUploads()
        return candidates.count
    }

    /// Sends the queue in order. Stops at the first failure that would fail the rest too —
    /// offline, over Strava's limit, no longer connected — and drops an entry Strava will never
    /// take. A session not loaded yet stays for the next sync.
    func syncPendingUploads(including finished: WorkoutSessionModel? = nil) async {
        guard isConnected, !isSyncingUploads else { return }
        isSyncingUploads = true
        defer { isSyncingUploads = false }

        for sessionId in pendingSessionIds {
            guard let session = finished?.id == sessionId ? finished : sessions.workoutSessions.first(where: { $0.id == sessionId }) else {
                continue
            }
            guard session.deletedAt == nil, session.stravaActivityId == nil else {
                dequeue(sessionId)
                continue
            }
            do {
                switch try await upload(session) {
                case .linked(let activityId):
                    dequeue(sessionId)
                    try? await sessions.setStravaActivityId(activityId, sessionId: sessionId)
                case .nothingToSend:
                    dequeue(sessionId)
                case .processing:
                    continue
                }
            } catch StravaError.processingFailed(let reason) {
                logger.trackEvent(eventName: "strava_upload_rejected", parameters: ["reason": reason], type: .warning)
                dequeue(sessionId)
            } catch StravaError.uploadFailed(let status) where (400..<500).contains(status) {
                logger.trackEvent(eventName: "strava_upload_rejected", parameters: ["status": status], type: .warning)
                dequeue(sessionId)
            } catch {
                logger.trackEvent(eventName: "strava_upload_error", parameters: ["error": error.localizedDescription], type: .warning)
                return
            }
        }
    }

    private func dequeue(_ sessionId: String) {
        pendingSessionIds.removeAll { $0 == sessionId }
        savePendingUploads()
    }

    // MARK: - Sending

    /// Uploads a finished workout with its sets. A workout sent twice — a retry, or the Live
    /// Activity and the tracker both finishing — is one activity, because Strava refuses the second
    /// as a duplicate of the first.
    func upload(_ session: WorkoutSessionModel) async throws -> UploadOutcome {
        guard let file = StravaStrengthFile(session: session, library: exercises.allExercises) else { return .nothingToSend }
        let activityId = try await upload(StravaUpload(
            name: session.name,
            description: description(for: session),
            externalId: "compound-\(session.id)",
            file: file
        ))
        return activityId.map { .linked(activityId: $0) } ?? .processing
    }

    /// Sends a session's name and description to the activity it was uploaded as, after an edit.
    func updateActivity(_ activityId: Int, from session: WorkoutSessionModel) async throws {
        let description = description(for: session)
        try await withAccessToken {
            try await self.service.updateActivity(id: activityId, name: session.name, description: description, accessToken: $0)
        }
    }

    func uploadTestActivity() async throws {
        let start = Date().addingTimeInterval(-1800)
        let session = WorkoutSessionModel(
            authorId: "",
            name: "Compound Test Upload",
            dateCreated: start,
            endedAt: Date(),
            notes: "Test upload from Compound — safe to delete.",
            exercises: [WorkoutExerciseModel(
                id: "test", authorId: "", templateId: "system-barbell-bench-press", name: "Barbell Bench Press",
                trackingMode: .weightReps, index: 0,
                sets: [WorkoutSetModel(id: "test", authorId: "", index: 0, reps: 10, weightKg: 60, isWarmup: false, completedAt: Date(), dateCreated: start)]
            )]
        )
        guard let file = StravaStrengthFile(session: session, library: []) else { return }
        _ = try await upload(StravaUpload(
            name: session.name,
            description: description(for: session),
            externalId: "compound-test-\(UUID().uuidString)",
            file: file
        ))
    }

    private func description(for session: WorkoutSessionModel) -> String? {
        StravaUpload.description(
            for: session,
            weightUnit: users.currentUser?.submittedWeightUnitPreference ?? .kilograms,
            distanceUnit: users.currentUser?.submittedDistanceUnitPreference ?? .kilometers
        )
    }

    /// The activity id, or `nil` if Strava was still processing after the wait. Strava processes
    /// an upload in under two seconds on average and asks to be polled no more than once a second.
    private func upload(_ upload: StravaUpload) async throws -> Int? {
        var status = try await withAccessToken { try await self.service.upload(upload, accessToken: $0) }
        for attempt in 0...pollAttempts {
            if let activityId = status.activityId ?? status.duplicateActivityId { return activityId }
            if let error = status.error { throw StravaError.processingFailed(error) }
            guard attempt < pollAttempts else { break }
            try await Task.sleep(for: pollInterval)
            let uploadId = status.id
            status = try await withAccessToken { try await self.service.uploadStatus(id: uploadId, accessToken: $0) }
        }
        return nil
    }
}
