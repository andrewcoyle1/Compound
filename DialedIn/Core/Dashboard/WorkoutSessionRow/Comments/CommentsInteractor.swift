//
//  CommentsInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

@MainActor
protocol CommentsInteractor: ReportInteractor {
    var currentUser: UserModel? { get }
    var followingUsers: [UserModel] { get }
    func getUser(userId: String) async throws -> UserModel
    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment]
    func addComment(_ comment: WorkoutSessionComment) async throws
    func deleteComment(id: String) async throws
    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws
}

extension CoreInteractor: CommentsInteractor { }
