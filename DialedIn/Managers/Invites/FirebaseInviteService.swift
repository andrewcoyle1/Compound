//
//  FirebaseInviteService.swift
//  DialedIn
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class FirebaseInviteService: InviteService {

    private var collection: CollectionReference {
        Firestore.firestore().collection("invites")
    }

    func fetchInvite(code: String) async throws -> InviteModel? {
        let snapshot = try await collection.document(code).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: InviteModel.self)
    }

    func fetchInvite(inviterId: String) async throws -> InviteModel? {
        let invites: [InviteModel] = try await collection
            .whereField(InviteModel.CodingKeys.inviterId.rawValue, isEqualTo: inviterId)
            .limit(to: 1)
            .getAllDocuments()
        return invites.first
    }

    func createInvite(_ invite: InviteModel) async throws {
        // Encoded first so a rules rejection reaches the caller; `setData(from:)` does not report it.
        let data = try Firestore.Encoder().encode(invite)
        try await collection.document(invite.code).setData(data)
    }

    func acceptInvite(code: String) async throws -> InviteAcceptance {
        let result: HTTPSCallableResult
        do {
            result = try await Functions.functions(region: "us-central1")
                .httpsCallable("acceptInvite")
                .call(["code": code])
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            throw Self.inviteError(FunctionsErrorCode(rawValue: error.code)) ?? error
        }
        guard
            let data = result.data as? [String: Any],
            let inviterId = data["inviter_id"] as? String,
            let youFollow = (data["you_follow"] as? String).flatMap(InviteAcceptance.Outcome.init),
            let theyFollow = (data["they_follow"] as? String).flatMap(InviteAcceptance.Outcome.init)
        else {
            throw AppError("Unexpected response from acceptInvite.")
        }
        return InviteAcceptance(inviterId: inviterId, youFollow: youFollow, theyFollow: theyFollow)
    }

    /// The codes `acceptInvite` throws, in `functions/lib.js` `planInviteAcceptance`.
    private static func inviteError(_ code: FunctionsErrorCode?) -> InviteError? {
        switch code {
        case .invalidArgument: .invalidCode
        case .notFound: .notFound
        case .failedPrecondition: .ownInvite
        case .resourceExhausted: .exhausted
        case .permissionDenied: .unavailable
        default: nil
        }
    }
}
