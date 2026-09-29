//
//  WorkoutSessionManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutSessionManager {

    private let likeService: any WorkoutSessionLikeService
    private let activeWorkoutSessionPersistence: any LocalDocumentPersistence<WorkoutSessionModel>

    private let userWorkoutSessionSyncEngine: CollectionSyncEngine<WorkoutSessionModel>
    private let followingWorkoutSessionSyncEngine: CollectionGroupSyncEngine<WorkoutSessionModel>
    
    // MARK: - Observable State

    var activeSession: WorkoutSessionModel?

    var workoutSessions: [WorkoutSessionModel] {
        userWorkoutSessionSyncEngine.currentCollection
    }
    
    var followingWorkoutSessions: [WorkoutSessionModel] {
        followingWorkoutSessionSyncEngine.currentCollection
    }

    /// Whether the following feed has answered once since sign-in, so an empty feed can be told
    /// apart from one still loading. `startListening` returns once its bulk load has landed (or
    /// failed, so an offline launch does not spin forever); following nobody answers at once.
    private(set) var hasLoadedFollowingSessions = false

    // MARK: - Init

    init(
        likeService: any WorkoutSessionLikeService,
        activeWorkoutSessionPersistence: any LocalDocumentPersistence<WorkoutSessionModel>,
        userWorkoutSessionSyncEngine: CollectionSyncEngine<WorkoutSessionModel>,
        followingWorkoutSessionSyncEngine: CollectionGroupSyncEngine<WorkoutSessionModel>
    ) {
        self.likeService = likeService
        self.activeWorkoutSessionPersistence = activeWorkoutSessionPersistence
        self.userWorkoutSessionSyncEngine = userWorkoutSessionSyncEngine
        self.followingWorkoutSessionSyncEngine = followingWorkoutSessionSyncEngine
        self.activeSession = try? activeWorkoutSessionPersistence.getDocument(managerKey: Keys.activeWorkoutSessionManagerKey)
    }
    
    // MARK: - Lifecycle

    func signIn(userId: String, followingIds: [String] = []) async {
        async let userWorkoutsSignIn: () = userWorkoutSessionSyncEngine.startListening { query in
            query.where("author_id", isEqualTo: userId)
        }

        await userWorkoutsSignIn
        await refreshFollowingSync(followingIds: followingIds)
    }

    func refreshFollowingSync(followingIds: [String]) async {
        guard !followingIds.isEmpty else {
            followingWorkoutSessionSyncEngine.stopListening()
            hasLoadedFollowingSessions = true
            return
        }
        await followingWorkoutSessionSyncEngine.startListening { query in
            FollowingQueries.sessions(query, followingIds: followingIds)
        }
        hasLoadedFollowingSessions = true
    }

    func signOut() {
        userWorkoutSessionSyncEngine.stopListening()
        followingWorkoutSessionSyncEngine.stopListening()
        hasLoadedFollowingSessions = false
    }

    func updateActiveSession(_ session: WorkoutSessionModel) throws {
        try activeWorkoutSessionPersistence.saveDocument(managerKey: Keys.activeWorkoutSessionManagerKey, session)
        self.activeSession = session
    }
    
    func endWorkoutSession(_ session: WorkoutSessionModel) async throws {
        try await self.saveWorkoutSession(session)
        try clearActiveSession()
    }
    
    func deleteActiveSession() throws {
        try clearActiveSession()
    }
    
    private func clearActiveSession() throws {
        try activeWorkoutSessionPersistence.saveDocument(managerKey: Keys.activeWorkoutSessionManagerKey, nil)
        self.activeSession = nil
    }
    
    func getLastWorkoutSessionForTemplate(templateId: String) async throws -> WorkoutSessionModel? {
        let sessions = try await userWorkoutSessionSyncEngine.getDocumentsAsync { session in
            session.workoutTemplateId == templateId
        }
        return sessions.sortedByKeyPath(keyPath: \.dateCreated, ascending: false).first
    }

    // MARK: - Write

    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws {
        try await userWorkoutSessionSyncEngine.saveDocument(session)
    }

    func deleteWorkoutSession(id: String) async throws {
        try await userWorkoutSessionSyncEngine.deleteDocument(id: id)
    }
    
    // MARK: - Read

    func getWorkoutSession(id: String) async throws -> WorkoutSessionModel {
        try await userWorkoutSessionSyncEngine.getDocumentAsync(id: id)
    }

    func getWorkoutSessions(ids: [String], limitTo: Int = 20) -> [WorkoutSessionModel] {
        let results = userWorkoutSessionSyncEngine.getDocuments(where: { ids.contains($0.id) })
        return Array(results.prefix(limitTo))
    }

    func getWorkoutSessionsByTemplateAndAuthor(templateId: String, authorId: String, limitTo: Int) async throws -> [WorkoutSessionModel] {
        try await userWorkoutSessionSyncEngine.getDocumentsAsync { query in
            query
                .where("workout_template_id", isEqualTo: templateId)
                .where("author_id", isEqualTo: authorId)
                .limit(to: limitTo)
        }
    }

    /// Anyone's sessions, newest first. The user engine's path is the *reader's* own
    /// `users/{uid}/workout_sessions`, so querying it for another author always came back empty;
    /// the collection group spans every user's subcollection, which the rules let any signed-in
    /// user read. Ordering needs the `author_id` + `date_created` index in `firestore.indexes.json`.
    /// The filter repeats the query's because the mock remote ignores query filters.
    func getWorkoutSessionsForAuthor(authorId: String, limitTo: Int = 20) async throws -> [WorkoutSessionModel] {
        try await followingWorkoutSessionSyncEngine.getDocumentsAsync { query in
            query
                .where("author_id", isEqualTo: authorId)
                .order(by: "date_created", descending: true)
                .limit(to: limitTo)
        }
        .filter { $0.authorId == authorId }
    }

    /// One session by anyone, for a notification tap. Already-synced sessions (the reader's own and
    /// those of people they follow) answer straight away; anything else is read through the same
    /// collection group as `getWorkoutSessionsForAuthor`, which needs the `author_id` + `id` index in
    /// `firestore.indexes.json`. The filter repeats the query's because the mock remote ignores it.
    func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel {
        if let synced = (workoutSessions + followingWorkoutSessions).first(where: { $0.id == id }) {
            return synced
        }
        let found = try await followingWorkoutSessionSyncEngine.getDocumentsAsync { query in
            query
                .where("author_id", isEqualTo: authorId)
                .where("id", isEqualTo: id)
                .limit(to: 1)
        }
        .first { $0.id == id }
        guard let found else { throw URLError(.fileDoesNotExist) }
        return found
    }

    func likeSession(sessionId: String, authorId: String, userId: String) async throws {
        try await likeService.likeSession(sessionId: sessionId, authorId: authorId, userId: userId)
    }

    func unlikeSession(sessionId: String, authorId: String, userId: String) async throws {
        try await likeService.unlikeSession(sessionId: sessionId, authorId: authorId, userId: userId)
    }

    /// `inTrainingProgramId` narrows the search to one program's sessions; `nil` searches them
    /// all, which is what every caller wanted before `previousWorkoutReference` was honoured.
    func getLastCompletedSessionForTemplate(
        templateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil
    ) async throws -> WorkoutSessionModel? {
        try await getLastCompletedSessionsForTemplate(
            templateId: templateId,
            authorId: authorId,
            inTrainingProgramId: inTrainingProgramId,
            limit: 1
        ).first
    }

    /// The last `limit` completed sessions for a template, most recent first.
    ///
    /// Smart progression needs more than one: a single missed session is a bad day, and only the
    /// second one in a row is a signal to deload.
    func getLastCompletedSessionsForTemplate(
        templateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil,
        limit: Int = 3
    ) async throws -> [WorkoutSessionModel] {
        // Check the already-loaded collection first (current user's sessions)
        let cached = userWorkoutSessionSyncEngine.currentCollection
            .filter { $0.workoutTemplateId == templateId && $0.endedAt != nil }
            .filter { inTrainingProgramId == nil || $0.trainingProgramId == inTrainingProgramId }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }

        return Array(cached.prefix(max(limit, 0)))
    }

    /// The last `limit` completed sessions that included a given exercise, whatever workout they
    /// were, most recent first.
    ///
    /// The template lookups above answer "when did I last do this workout"; this one answers "when
    /// did I last do this exercise", which is what `.anyExercise` means and what the other two
    /// scopes fall back to when the template has no history for the exercise.
    func getLastCompletedSessionsContainingExercise(
        exerciseTemplateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil,
        limit: Int = 3
    ) async throws -> [WorkoutSessionModel] {
        let cached = userWorkoutSessionSyncEngine.currentCollection
            .filter { $0.endedAt != nil }
            .filter { $0.exercises.contains(where: { $0.templateId == exerciseTemplateId }) }
            .filter { inTrainingProgramId == nil || $0.trainingProgramId == inTrainingProgramId }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }

        return Array(cached.prefix(max(limit, 0)))
    }
}

extension CoreInteractor {
    // MARK: WorkoutSessionManager

    var activeSession: WorkoutSessionModel? {
        workoutSessionManager.activeSession
    }
    
    func updateActiveSession(_ session: WorkoutSessionModel) throws {
        try workoutSessionManager.updateActiveSession(session)
    }

    var workoutSessions: [WorkoutSessionModel] {
        workoutSessionManager.workoutSessions
    }

    var followingWorkoutSessions: [WorkoutSessionModel] {
        workoutSessionManager.followingWorkoutSessions
    }

    var hasLoadedFollowingSessions: Bool {
        workoutSessionManager.hasLoadedFollowingSessions
    }

    /// Every session by `authorId` this device holds: the reader's own history, or what the
    /// following feed has synced of someone they follow.
    func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] {
        authorId == currentUser?.userId ? workoutSessions : followingWorkoutSessions.filter { $0.authorId == authorId }
    }

    var restEndTime: Date? {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        return hkWorkoutManager.restEndTime
        #else
        return nil
        #endif
    }

    func endWorkoutSession(_ session: WorkoutSessionModel) async throws {
        try await workoutSessionManager.endWorkoutSession(session)
    }
    
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws {
        try await workoutSessionManager.saveWorkoutSession(session)
    }

    func deleteWorkoutSession(id: String) async throws {
        try await workoutSessionManager.deleteWorkoutSession(id: id)
    }

    func getWorkoutSession(id: String) async throws -> WorkoutSessionModel {
        try await workoutSessionManager.getWorkoutSession(id: id)
    }

    func getLastWorkoutSessionForTemplate(templateId: String) async throws -> WorkoutSessionModel? {
        try await workoutSessionManager.getLastWorkoutSessionForTemplate(templateId: templateId)
    }
    
    func getWorkoutSessions(ids: [String], limitTo: Int = 20) -> [WorkoutSessionModel] {
        workoutSessionManager.getWorkoutSessions(ids: ids, limitTo: limitTo)
    }

    func getWorkoutSessionsByTemplateAndAuthor(templateId: String, authorId: String, limitTo: Int) async throws -> [WorkoutSessionModel] {
        try await workoutSessionManager.getWorkoutSessionsByTemplateAndAuthor(templateId: templateId, authorId: authorId, limitTo: limitTo)
    }

    func getWorkoutSessionsForAuthor(authorId: String, limitTo: Int = 20) async throws -> [WorkoutSessionModel] {
        try await workoutSessionManager.getWorkoutSessionsForAuthor(authorId: authorId, limitTo: limitTo)
    }

    func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel {
        try await workoutSessionManager.fetchWorkoutSession(id: id, authorId: authorId)
    }

    func fetchWorkoutSessions(authorId: String, limit: Int) async throws -> [WorkoutSessionModel] {
        try await workoutSessionManager.getWorkoutSessionsForAuthor(authorId: authorId, limitTo: limit)
    }

    func getLastCompletedSessionForTemplate(
        templateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil
    ) async throws -> WorkoutSessionModel? {
        try await workoutSessionManager.getLastCompletedSessionForTemplate(
            templateId: templateId,
            authorId: authorId,
            inTrainingProgramId: inTrainingProgramId
        )
    }

    func getLastCompletedSessionsForTemplate(
        templateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil,
        limit: Int = 3
    ) async throws -> [WorkoutSessionModel] {
        try await workoutSessionManager.getLastCompletedSessionsForTemplate(
            templateId: templateId,
            authorId: authorId,
            inTrainingProgramId: inTrainingProgramId,
            limit: limit
        )
    }

    func getLastCompletedSessionsContainingExercise(
        exerciseTemplateId: String,
        authorId: String,
        inTrainingProgramId: String? = nil,
        limit: Int = 3
    ) async throws -> [WorkoutSessionModel] {
        try await workoutSessionManager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: exerciseTemplateId,
            authorId: authorId,
            inTrainingProgramId: inTrainingProgramId,
            limit: limit
        )
    }

    func likeSession(sessionId: String, authorId: String, userId: String) async throws {
        try await workoutSessionManager.likeSession(sessionId: sessionId, authorId: authorId, userId: userId)
        guard authorId != userId else { return }
        let actor = userManager.currentUser
        let notification = ActivityNotificationModel(
            id: "like_\(sessionId)_\(userId)",
            type: .like,
            actorId: userId,
            actorName: actor?.fullNameCalculated ?? "Someone",
            actorImageUrl: actor?.submittedProfileImage,
            sessionId: sessionId,
            sessionAuthorId: authorId,
            commentText: nil,
            dateCreated: .now,
            isRead: false
        )
        try? await activityNotificationManager.addNotification(notification, userId: authorId)
    }

    func unlikeSession(sessionId: String, authorId: String, userId: String) async throws {
        try await workoutSessionManager.unlikeSession(sessionId: sessionId, authorId: authorId, userId: userId)
        guard authorId != userId else { return }
        let notifId = "like_\(sessionId)_\(userId)"
        try? await activityNotificationManager.deleteNotification(id: notifId, userId: authorId)
    }

    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] {
        try await commentsManager.fetchComments(sessionId: sessionId)
    }

    func addComment(_ comment: WorkoutSessionComment) async throws {
        try await commentsManager.addComment(comment)
        var parentAuthorId: String?
        if let parentId = comment.parentId {
            parentAuthorId = try? await commentsManager.fetchComments(sessionId: comment.sessionId)
                .first(where: { $0.id == parentId })?.authorId
        }
        for (recipient, notification) in comment.activityNotifications(parentAuthorId: parentAuthorId) {
            try? await activityNotificationManager.addNotification(notification, userId: recipient)
        }
    }

    func deleteComment(id: String) async throws {
        try await commentsManager.deleteComment(id: id)
    }

    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws {
        try await commentsManager.toggleCommentLike(id: id, userId: userId, isLiked: isLiked)
    }
}
