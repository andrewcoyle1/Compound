//
//  InviteService.swift
//  DialedIn
//

import Foundation

@MainActor
protocol InviteService: AnyObject {
    func fetchInvite(code: String) async throws -> InviteModel?
    func fetchInvite(inviterId: String) async throws -> InviteModel?
    /// Throws if the code is taken: rules allow create, never update.
    func createInvite(_ invite: InviteModel) async throws
    /// Calls the `acceptInvite` Cloud Function, which does every write.
    func acceptInvite(code: String) async throws -> InviteAcceptance
}

@MainActor
final class InviteManager {
    private let service: InviteService

    init(service: InviteService) {
        self.service = service
    }

    /// The user's one invite, created on first use. A generated code that is already taken is
    /// redrawn; `generate` is injectable so a test can force the collision.
    func invite(for userId: String, generate: () -> String = InviteCode.random) async throws -> InviteModel {
        if let existing = try await service.fetchInvite(inviterId: userId) { return existing }
        // ponytail: check-then-create races, but two users drawing one of 31^8 codes in the same
        // instant is not worth a transaction; the create fails rather than overwriting either way.
        for _ in 0..<5 {
            let code = generate()
            guard try await service.fetchInvite(code: code) == nil else { continue }
            let invite = InviteModel(code: code, inviterId: userId)
            try await service.createInvite(invite)
            return invite
        }
        throw AppError("Couldn't create an invite code. Please try again.")
    }

    func acceptInvite(code: String) async throws -> InviteAcceptance {
        guard let code = InviteCode.normalised(code) else { throw InviteError.invalidCode }
        return try await service.acceptInvite(code: code)
    }
}

/// Invites in memory, validated the way the Cloud Function validates them. Seeded with
/// `sampleCode` from `user1` so the mock scenario and `STARTSCREEN_INVITE` have one to accept.
@MainActor
final class MockInviteService: InviteService {
    static let sampleCode = "PUSH2345"

    private(set) var invites: [String: InviteModel]
    /// Who the mock signed-in user is, for refusing their own invite.
    private let callerId: String

    init(invites: [InviteModel] = [InviteModel(code: MockInviteService.sampleCode, inviterId: "user1")], callerId: String = "mock_user_123") {
        self.invites = Dictionary(uniqueKeysWithValues: invites.map { ($0.code, $0) })
        self.callerId = callerId
    }

    func fetchInvite(code: String) async throws -> InviteModel? {
        invites[code]
    }

    func fetchInvite(inviterId: String) async throws -> InviteModel? {
        invites.values.first { $0.inviterId == inviterId }
    }

    func createInvite(_ invite: InviteModel) async throws {
        guard invites[invite.code] == nil else { throw InviteError.unavailable }
        invites[invite.code] = invite
    }

    func acceptInvite(code: String) async throws -> InviteAcceptance {
        guard let invite = invites[code] else { throw InviteError.notFound }
        guard invite.inviterId != callerId else { throw InviteError.ownInvite }
        guard invite.uses < invite.maxUses else { throw InviteError.exhausted }
        invites[code] = InviteModel(
            code: invite.code,
            inviterId: invite.inviterId,
            dateCreated: invite.dateCreated,
            uses: invite.uses + 1,
            maxUses: invite.maxUses
        )
        return InviteAcceptance(inviterId: invite.inviterId, youFollow: .following, theyFollow: .following)
    }
}
