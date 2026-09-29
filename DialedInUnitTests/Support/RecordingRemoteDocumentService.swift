//
//  RecordingRemoteDocumentService.swift
//  DialedInUnitTests
//
//  `MockRemoteDocumentService.updateDocument` re-emits the unchanged document rather than applying
//  the data, so a test cannot see a partial update through `currentUser`. This wraps the mock and
//  records what each update and save asked for, which is the thing such a test wants to assert on.
//

import Foundation
import SwiftfulDataManagers
@testable import DialedIn

final class RecordingRemoteDocumentService<T: DataSyncModelProtocol>: RemoteDocumentService, @unchecked Sendable {

    private let mock: MockRemoteDocumentService<T>
    private(set) var updates: [[String: any DMCodableSendable]] = []
    private(set) var saves: [T] = []

    init(document: T?) {
        mock = MockRemoteDocumentService(document: document)
    }

    func getDocument(id: String) async throws -> T { try await mock.getDocument(id: id) }
    func saveDocument(_ model: T) async throws {
        saves.append(model)
        try await mock.saveDocument(model)
    }
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> { mock.streamDocument(id: id) }
    func deleteDocument(id: String) async throws { try await mock.deleteDocument(id: id) }

    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws {
        updates.append(data)
        try await mock.updateDocument(id: id, data: data)
    }

    /// The last value written for `key`, as an array of strings, or nil if never written.
    func lastStrings(for key: String) -> [String]? {
        updates.reversed().compactMap { $0[key] as? [String] }.first
    }
}
