//
//  FirebaseShareService.swift
//  DialedIn
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirebaseShareService: ShareService {

    private var collection: CollectionReference {
        Firestore.firestore().collection("shares")
    }

    func sendShare(_ share: ShareModel) async throws {
        // Encoded first so a rules rejection reaches the caller; `setData(from:)` does not report it.
        let data = try Firestore.Encoder().encode(share)
        try await collection.document(share.id).setData(data)
    }

    func fetchShare(id: String) async throws -> ShareModel {
        try await collection.document(id).getDocument(as: ShareModel.self)
    }

    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws {
        try await collection.document(id).updateData([ShareModel.CodingKeys.status.rawValue: status.rawValue])
    }
}
