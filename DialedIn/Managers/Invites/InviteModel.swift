//
//  InviteModel.swift
//  DialedIn
//
//  `invites/{code}`: one per inviter, created the first time they share it and reused after. The
//  `acceptInvite` Cloud Function reads it, follows both ways and counts the use; clients never
//  update it.
//

import Foundation

struct InviteModel: Codable, Equatable, Sendable {
    static let maxUses = 50

    let code: String
    let inviterId: String
    let dateCreated: Date
    let uses: Int
    let maxUses: Int

    init(code: String, inviterId: String, dateCreated: Date = .now, uses: Int = 0, maxUses: Int = InviteModel.maxUses) {
        self.code = code
        self.inviterId = inviterId
        self.dateCreated = dateCreated
        self.uses = uses
        self.maxUses = maxUses
    }

    enum CodingKeys: String, CodingKey {
        case code
        case inviterId = "inviter_id"
        case dateCreated = "date_created"
        case uses
        case maxUses = "max_uses"
    }

    /// `compound://join/<code>`, handled by `DeepLink(url:)`.
    var link: URL {
        // Safe: codes use the URL-safe invite alphabet, and URL(string:) percent-encodes anything else.
        URL(string: "compound://join/\(code)")!
    }

    /// What the share sheet sends.
    var shareMessage: String {
        "Train with me on Compound: \(link.absoluteString)"
    }
}

/// Eight characters from an alphabet with no 0/O, 1/I/L, so a code read aloud or retyped from
/// another phone survives. Mirrored in `functions/lib.js` and `firestore.rules`.
enum InviteCode {
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let length = 8

    static func random() -> String {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> String {
        // Safe: `alphabet` is a non-empty literal.
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    /// Uppercased with spaces and dashes dropped, or nil if what is left is not a code — so a code
    /// typed as "push 2345" or "push-2345" still works.
    static func normalised(_ raw: String) -> String? {
        let code = raw.uppercased().filter { $0 != " " && $0 != "-" }
        guard code.count == length, code.allSatisfy(alphabet.contains) else { return nil }
        return code
    }
}

/// What accepting did, from the accepting user's side. A private profile gets a request instead of
/// a follow, in either direction.
struct InviteAcceptance: Equatable, Sendable {
    enum Outcome: String, Sendable {
        case following
        case requested
    }

    let inviterId: String
    /// The accepting user following the inviter.
    let youFollow: Outcome
    /// The inviter following the accepting user.
    let theyFollow: Outcome

    /// The toast after accepting.
    func message(inviterName: String) -> String {
        switch (youFollow, theyFollow) {
        case (.following, .following): String(localized: "You're now following each other")
        case (.following, .requested): String(localized: "You're following \(inviterName). They've asked to follow you.")
        case (.requested, .following): String(localized: "\(inviterName) is following you. Your follow request is waiting.")
        case (.requested, .requested): String(localized: "Follow requests sent both ways")
        }
    }
}

enum InviteError: LocalizedError, Equatable {
    case invalidCode
    case notFound
    case ownInvite
    case exhausted
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidCode: String(localized: "That doesn't look like an invite code. Codes are 8 letters and numbers.")
        case .notFound: String(localized: "That invite code doesn't exist.")
        case .ownInvite: String(localized: "That's your own invite. Send it to a friend.")
        case .exhausted: String(localized: "That invite has been used too many times.")
        case .unavailable: String(localized: "That invite isn't available.")
        }
    }
}
