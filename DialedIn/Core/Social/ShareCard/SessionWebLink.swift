//
//  SessionWebLink.swift
//  DialedIn
//

import Foundation

/// The public web page for a finished session, rendered by the `sessionPage` Cloud Function
/// behind Firebase Hosting's `/s/**` rewrite.
enum SessionWebLink {

    /// Dev and prod share one Firebase project, so one host serves both.
    static let baseURL = "https://dialed-c3cb5.web.app/s"

    /// The link, or nil where the page would answer 404: a private or unknown author, or a
    /// session that is unfinished, deleted or hidden by moderation.
    static func url(for session: WorkoutSessionModel, author: UserModel?) -> URL? {
        guard let author, author.isPrivate != true,
              session.endedAt != nil, session.deletedAt == nil, session.hidden != true
        else { return nil }
        return URL(string: "\(baseURL)/\(session.authorId)/\(session.id)")
    }
}
