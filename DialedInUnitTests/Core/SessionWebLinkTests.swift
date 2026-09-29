//
//  SessionWebLinkTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// "Copy Link" offers the web page only where the `sessionPage` function would render it.
struct SessionWebLinkTests {

    let start = Date(timeIntervalSince1970: 1_790_000_000)

    func session(endedAt: Date?? = .none, deletedAt: Date? = nil, hidden: Bool? = nil) -> WorkoutSessionModel {
        var session = WorkoutSessionModel(
            id: "s1", authorId: "a1", name: "Push", dateCreated: start,
            endedAt: endedAt ?? start.addingTimeInterval(3600), exercises: [], deletedAt: deletedAt
        )
        session.hidden = hidden
        return session
    }

    func author(isPrivate: Bool? = nil) -> UserModel {
        UserModel(userId: "a1", isPrivate: isPrivate)
    }

    @Test func publicFinishedSessionLinksToItsPage() {
        #expect(SessionWebLink.url(for: session(), author: author())?.absoluteString == "https://dialed-c3cb5.web.app/s/a1/s1")
        #expect(SessionWebLink.url(for: session(), author: author(isPrivate: false)) != nil)
    }

    @Test func noLinkWhereThePageWouldRefuse() {
        #expect(SessionWebLink.url(for: session(), author: author(isPrivate: true)) == nil)
        #expect(SessionWebLink.url(for: session(), author: nil) == nil)
        #expect(SessionWebLink.url(for: session(hidden: true), author: author()) == nil)
        #expect(SessionWebLink.url(for: session(deletedAt: start), author: author()) == nil)
        #expect(SessionWebLink.url(for: session(endedAt: .some(nil)), author: author()) == nil)
    }
}
