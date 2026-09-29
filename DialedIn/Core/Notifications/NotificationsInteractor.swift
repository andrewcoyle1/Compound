//
//  NotificationsInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NotificationsInteractor: FollowInteractor {
    var activityNotifications: [ActivityNotificationModel] { get }
    var incomingFollowRequests: [FollowRequestModel] { get }
    func fetchActivityNotifications() async throws
    func markActivityNotificationsRead() async throws
    func deleteActivityNotification(id: String) async throws
    func clearAllDeliveredNotifications()
    func fetchIncomingFollowRequests() async throws
    func respondToFollowRequest(requesterId: String, accept: Bool) async throws
    func getUser(userId: String) async throws -> UserModel
    func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel
    // MARK: - Sharing
    func fetchShare(id: String) async throws -> ShareModel
    // MARK: - GroupedNotifications
    var canLoadMoreActivityNotifications: Bool { get }
    func fetchMoreActivityNotifications() async throws
    func markActivityNotificationsRead(ids: [String]) async throws
    // MARK: - Challenges
    func fetchChallenge(id: String) async throws -> ChallengeModel
}

extension CoreInteractor: NotificationsInteractor { }
