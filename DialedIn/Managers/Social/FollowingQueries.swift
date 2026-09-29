//
//  FollowingQueries.swift
//  DialedIn
//
//  The two listeners that run over the people a user follows: their profiles, and their workout
//  sessions through the `workout_sessions` collection group. Both start at sign-in and restart on
//  every follow or unfollow, so their bounds decide most of what a launch costs in reads.
//

import Foundation

enum FollowingQueries {

    /// Firestore rejects an `in` filter with more than 30 values. Past that the listener failed to
    /// attach and retried with backoff indefinitely, so the feed and the circle went empty for
    /// anyone following more than 30 people. Capping keeps the first 30 working.
    static let maxInValues = 30

    /// The feed shows followed sessions newest first, and the circle counts this week's. Neither
    /// needs a followed athlete's whole history, which the unbounded listener read in full —
    /// twice, since the sync engine bulk-loads before its listener's initial snapshot — on every
    /// launch and every follow. Needs the `author_id` + `date_created` collection-group index,
    /// which `firestore.indexes.json` already declares.
    static let sessionLimit = 200

    /// Unique ids, in order, at most `maxInValues` of them.
    static func cappedIds(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return Array(ids.filter { seen.insert($0).inserted }.prefix(maxInValues))
    }

    static func sessions(_ query: QueryBuilder, followingIds: [String]) -> QueryBuilder {
        query
            .where("author_id", in: cappedIds(followingIds))
            .order(by: "date_created", descending: true)
            .limit(to: sessionLimit)
    }

    static func users(_ query: QueryBuilder, followingIds: [String]) -> QueryBuilder {
        query.where("user_id", in: cappedIds(followingIds))
    }
}
