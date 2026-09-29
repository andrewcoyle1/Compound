//
//  UserManagerAccountDeletionTests.swift
//  DialedInUnitTests
//
//  Deleting the user document starts the onUserDeleted Cloud Function, which deletes everything
//  under it. A listener still attached when that happens would, once Auth is gone too, log a
//  permission error for every document it loses — so the listener has to stop first.
//

import Testing
import Foundation
import SwiftfulDataManagers
@testable import DialedIn

@MainActor
struct UserManagerAccountDeletionTests {

    @Test("Test Deleting The User Stops The Listener Before Deleting The Document")
    func testDeletingTheUserStopsTheListenerBeforeDeletingTheDocument() async throws {
        let user = UserModel.mock
        let remote = OrderRecordingUserRemote(user: user)
        let manager = UserManager(
            queryService: MockUserQueryService(),
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: remote,
                managerKey: TestManagers.key("user"),
                enableLocalPersistence: false
            ),
            followingUsersSyncEngine: TestManagers.collectionEngine([UserModel](), key: "following-users"),
            privateSettingsSyncEngine: TestManagers.documentEngine(nil as PrivateUserSettings?, key: "private")
        )
        try await manager.signIn(auth: UserAuthInfo(uid: user.userId), isNewUser: false)
        #expect(await TestManagers.eventually { manager.currentUser != nil })

        try await manager.deleteCurrentUser(userId: user.userId)

        #expect(remote.events == ["listenerStopped", "delete:\(user.userId)"])
        #expect(manager.currentUser == nil)
    }
}

/// Wraps the mock and records, in order, when the document stream is torn down and when a delete
/// is sent.
nonisolated private final class OrderRecordingUserRemote: RemoteDocumentService, @unchecked Sendable {

    private let mock: MockRemoteDocumentService<UserModel>
    private let lock = NSLock()
    private var recorded: [String] = []

    var events: [String] { lock.withLock { recorded } }

    init(user: UserModel) {
        mock = MockRemoteDocumentService(document: user)
    }

    private func record(_ event: String) {
        lock.withLock { recorded.append(event) }
    }

    func getDocument(id: String) async throws -> UserModel { try await mock.getDocument(id: id) }
    func saveDocument(_ model: UserModel) async throws { try await mock.saveDocument(model) }
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws {
        try await mock.updateDocument(id: id, data: data)
    }

    func deleteDocument(id: String) async throws {
        record("delete:\(id)")
        try await mock.deleteDocument(id: id)
    }

    func streamDocument(id: String) -> AsyncThrowingStream<UserModel?, Error> {
        let upstream = mock.streamDocument(id: id)
        return AsyncThrowingStream { continuation in
            let forward = Task {
                do {
                    for try await value in upstream { continuation.yield(value) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [weak self] _ in
                forward.cancel()
                self?.record("listenerStopped")
            }
        }
    }
}
