//
//  FirestoreSemanticsRemotes.swift
//  CompoundUnitTests
//
//  The mock remotes replace a saved document whole, which hides the bug these wrappers exist to
//  show: Firestore's merge keeps a field the save left out, and merges a map key by key.
//

import Foundation
import SwiftfulDataManagers
@testable import Compound

/// Applies a save to the stored document as Firestore would: a `ReplacesClearedFields` model
/// through the merge fields `FirestoreFieldWrite` asks for (a field it leaves out is deleted, a map
/// replaced), anything else as `setData(merge: true)` (a nil field skipped, maps merged by key).
enum FirestoreSaveSemantics {

    static func apply<T: DataSyncModelProtocol>(_ model: T, onto stored: T?) throws -> T {
        guard let stored, stored.id == model.id else { return model }
        let saved = try json(model)
        var merged = try json(stored)
        if let write = try FirestoreFieldWrite.replacing(model) {
            for key in write.mergeFields {
                merged[key] = saved[key]
            }
        } else {
            merged = deepMerge(merged, saved)
        }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: merged))
    }

    private static func json<T: Encodable>(_ value: T) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:]
    }

    private static func deepMerge(_ stored: [String: Any], _ saved: [String: Any]) -> [String: Any] {
        stored.merging(saved) { old, new in
            guard let old = old as? [String: Any], let new = new as? [String: Any] else { return new }
            return deepMerge(old, new)
        }
    }
}

final class FirestoreSemanticsDocumentService<T: DataSyncModelProtocol>: RemoteDocumentService, @unchecked Sendable {

    private let mock: MockRemoteDocumentService<T>

    init(_ mock: MockRemoteDocumentService<T>) {
        self.mock = mock
    }

    func saveDocument(_ model: T) async throws {
        let stored = try? await mock.getDocument(id: model.id)
        try await mock.saveDocument(FirestoreSaveSemantics.apply(model, onto: stored))
    }

    func getDocument(id: String) async throws -> T { try await mock.getDocument(id: id) }
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws { try await mock.updateDocument(id: id, data: data) }
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> { mock.streamDocument(id: id) }
    func deleteDocument(id: String) async throws { try await mock.deleteDocument(id: id) }
}

final class FirestoreSemanticsCollectionService<T: DataSyncModelProtocol>: RemoteCollectionService, @unchecked Sendable {

    private let mock: MockRemoteCollectionService<T>

    init(_ mock: MockRemoteCollectionService<T>) {
        self.mock = mock
    }

    func saveDocument(_ model: T) async throws {
        let stored = try? await mock.getDocument(id: model.id)
        try await mock.saveDocument(FirestoreSaveSemantics.apply(model, onto: stored))
    }

    func getCollection() async throws -> [T] { try await mock.getCollection() }
    func getDocument(id: String) async throws -> T { try await mock.getDocument(id: id) }
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> { mock.streamDocument(id: id) }
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws { try await mock.updateDocument(id: id, data: data) }
    func streamCollection() -> AsyncThrowingStream<[T], Error> { mock.streamCollection() }
    func streamCollection(query: QueryBuilder) -> AsyncThrowingStream<[T], Error> { mock.streamCollection(query: query) }
    func streamCollectionUpdates() -> (updates: AsyncThrowingStream<T, Error>, deletions: AsyncThrowingStream<String, Error>) { mock.streamCollectionUpdates() }
    func streamCollectionUpdates(query: QueryBuilder) -> (updates: AsyncThrowingStream<T, Error>, deletions: AsyncThrowingStream<String, Error>) { mock.streamCollectionUpdates(query: query) }
    func deleteDocument(id: String) async throws { try await mock.deleteDocument(id: id) }
    func getDocuments(query: QueryBuilder) async throws -> [T] { try await mock.getDocuments(query: query) }
}
