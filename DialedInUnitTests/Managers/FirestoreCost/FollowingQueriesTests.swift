//
//  FollowingQueriesTests.swift
//  DialedInUnitTests
//

import Foundation
import Testing
import SwiftfulDataManagers
@testable import DialedIn

/// Records the queries a collection-group engine hands its remote. The mock remote ignores
/// filters and limits, so the query itself is the only place to see them.
@MainActor
final class RecordingRemoteCollectionGroupService: RemoteCollectionGroupService {
    private(set) var queries: [QueryBuilder] = []

    func getDocuments(query: QueryBuilder) async throws -> [WorkoutSessionModel] {
        queries.append(query)
        return []
    }

    func streamCollection(query: QueryBuilder) -> AsyncThrowingStream<[WorkoutSessionModel], Error> {
        queries.append(query)
        return AsyncThrowingStream { _ in }
    }

    func streamCollectionUpdates(query: QueryBuilder) -> (
        updates: AsyncThrowingStream<WorkoutSessionModel, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        queries.append(query)
        return (AsyncThrowingStream { _ in }, AsyncThrowingStream { _ in })
    }
}

@Suite("FollowingQueries")
@MainActor
struct FollowingQueriesTests {

    private func ids(_ count: Int) -> [String] {
        (0..<count).map { "user-\($0)" }
    }

    private func inValues(_ query: QueryBuilder, field: String) -> [String]? {
        query.getFilters().first { $0.field == field && $0.operator == .in }?.value as? [String]
    }

    @Test("The following-sessions query is newest first and limited")
    func sessionsQueryIsBounded() {
        let query = FollowingQueries.sessions(QueryBuilder(), followingIds: ids(3))

        #expect(inValues(query, field: "author_id") == ids(3))
        #expect(query.getOrders() == [QueryOrder(field: "date_created", descending: true)])
        #expect(query.getLimit() == FollowingQueries.sessionLimit)
    }

    @Test("Both following queries stay within Firestore's 30-value in filter")
    func inFiltersAreCapped() {
        let many = ids(45)

        #expect(inValues(FollowingQueries.sessions(QueryBuilder(), followingIds: many), field: "author_id") == ids(30))
        #expect(inValues(FollowingQueries.users(QueryBuilder(), followingIds: many), field: "user_id") == ids(30))
    }

    @Test("Duplicate ids do not use up the in filter's slots")
    func duplicatesAreDropped() {
        #expect(FollowingQueries.cappedIds(["a", "b", "a", "c", "b"]) == ["a", "b", "c"])
    }

    @Test("The session manager's following listener uses the bounded query")
    func workoutSessionManagerUsesBoundedQuery() async {
        let remote = RecordingRemoteCollectionGroupService()
        let manager = WorkoutSessionManager(
            likeService: MockWorkoutSessionLikeService(),
            activeWorkoutSessionPersistence: MockLocalDocumentPersistence<WorkoutSessionModel>(),
            userWorkoutSessionSyncEngine: TestManagers.collectionEngine([WorkoutSessionModel](), key: "workout-sessions"),
            followingWorkoutSessionSyncEngine: CollectionGroupSyncEngine<WorkoutSessionModel>(
                remote: remote,
                managerKey: TestManagers.key("following-sessions"),
                enableLocalPersistence: false
            )
        )

        await manager.refreshFollowingSync(followingIds: ids(40))

        #expect(!remote.queries.isEmpty)
        for query in remote.queries {
            #expect(query.getLimit() == FollowingQueries.sessionLimit)
            #expect(inValues(query, field: "author_id")?.count == FollowingQueries.maxInValues)
        }
        manager.signOut()
    }
}
