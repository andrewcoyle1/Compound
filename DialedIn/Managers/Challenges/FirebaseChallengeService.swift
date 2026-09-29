//
//  FirebaseChallengeService.swift
//  DialedIn
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirebaseChallengeService: ChallengeService {

    private var collection: CollectionReference {
        Firestore.firestore().collection("challenges")
    }

    func fetchChallenges(userId: String) async throws -> [ChallengeModel] {
        let snapshot = try await collection
            .whereField(ChallengeModel.CodingKeys.memberIds.rawValue, arrayContains: userId)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ChallengeModel.self) }
    }

    func fetchChallenge(id: String) async throws -> ChallengeModel {
        try await collection.document(id).getDocument(as: ChallengeModel.self)
    }

    func fetchProgress(challengeId: String) async throws -> [String: Int] {
        let snapshot = try await collection.document(challengeId).collection("progress").getDocuments()
        var result: [String: Int] = [:]
        for document in snapshot.documents {
            if let progress = try? document.data(as: ChallengeProgressModel.self) {
                result[document.documentID] = progress.sessions
            }
        }
        return result
    }

    func createChallenge(_ challenge: ChallengeModel) async throws {
        // Encoded first so a rules rejection reaches the caller; `setData(from:)` does not report it.
        let data = try Firestore.Encoder().encode(challenge)
        try await collection.document(challenge.id).setData(data)
    }

    func leaveChallenge(id: String, userId: String) async throws {
        try await collection.document(id).updateData([
            ChallengeModel.CodingKeys.memberIds.rawValue: FieldValue.arrayRemove([userId])
        ])
    }
}
