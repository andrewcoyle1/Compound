//
//  ReplacesClearedFields.swift
//  Compound
//
//  The save path every sync engine's Firestore writes go through. `SwiftfulDataManagers+Alias`
//  points `FirebaseRemoteCollectionService` and `FirebaseRemoteDocumentService` at the two
//  services below, so `Dependencies` builds these without naming them.
//

@preconcurrency import FirebaseFirestore
import SwiftfulDataManagers
import SwiftfulDataManagersFirebase

/// A model whose save writes exactly what it holds: a field it leaves out (nil) is deleted, and a
/// map is replaced whole.
///
/// The package saves with `setData(from:merge: true)`. A merge skips a nil field and merges a
/// nested map key by key, so a cleared note, end date or nutrient never reached Firestore and came
/// back on the next sync, and a goal whose objective changed kept both objective keys and stopped
/// decoding. A conforming model's save lists each of its `CodingKeys` as a merge field instead.
/// Fields it does not declare, such as one only another client writes, are still left alone.
///
/// Adopt it only where the app owns every declared field: a model holding a field somebody else
/// writes (likes, counts, a profile created at sign-in from partial data) would delete theirs when
/// its own copy is nil.
protocol ReplacesClearedFields {
    associatedtype CodingKeys: CodingKey & CaseIterable
}

enum FirestoreFieldWrite {

    /// The data and merge fields for saving `model`, or nil when it keeps the package's merge.
    static func replacing<T: Encodable>(_ model: T) throws -> (data: [String: Any], mergeFields: [String])? {
        guard let owned = model as? any ReplacesClearedFields else { return nil }
        var data = try Firestore.Encoder().encode(model)
        for key in declaredFields(of: owned) where data[key] == nil {
            data[key] = FieldValue.delete()
        }
        return (data, Array(data.keys))
    }

    private static func declaredFields<M: ReplacesClearedFields>(of _: M) -> [String] {
        M.CodingKeys.allCases.map(\.stringValue)
    }

    /// Saves a conforming model, returning false for any other so the caller merges it as before.
    /// Synchronous, as the package's `setData(from:merge:)` is: it does not wait for the server, so
    /// an offline save still lands in the local cache and syncs later.
    static func saveReplacing<T: DataSyncModelProtocol>(_ model: T, collectionPath: String?) throws -> Bool {
        guard let write = try replacing(model) else { return false }
        guard let collectionPath else { throw FirebaseServiceError.collectionPathNotAvailable }
        Firestore.firestore().collection(collectionPath).document(model.id)
            .setData(write.data, mergeFields: write.mergeFields)
        return true
    }
}

@MainActor
final class FirestoreCollectionService<T: DataSyncModelProtocol>: RemoteCollectionService {

    private let base: SwiftfulDataManagersFirebase.FirebaseRemoteCollectionService<T>
    private let collectionPath: () -> String?

    init(collectionPath: @escaping () -> String?) {
        self.base = .init(collectionPath: collectionPath)
        self.collectionPath = collectionPath
    }

    func saveDocument(_ model: T) async throws {
        guard try FirestoreFieldWrite.saveReplacing(model, collectionPath: collectionPath()) else {
            return try await base.saveDocument(model)
        }
    }

    func getCollection() async throws -> [T] { try await base.getCollection() }
    func getDocument(id: String) async throws -> T { try await base.getDocument(id: id) }
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> { base.streamDocument(id: id) }
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws { try await base.updateDocument(id: id, data: data) }
    func streamCollection() -> AsyncThrowingStream<[T], Error> { base.streamCollection() }
    func streamCollection(query: QueryBuilder) -> AsyncThrowingStream<[T], Error> { base.streamCollection(query: query) }
    func streamCollectionUpdates() -> (updates: AsyncThrowingStream<T, Error>, deletions: AsyncThrowingStream<String, Error>) { base.streamCollectionUpdates() }
    func streamCollectionUpdates(query: QueryBuilder) -> (updates: AsyncThrowingStream<T, Error>, deletions: AsyncThrowingStream<String, Error>) { base.streamCollectionUpdates(query: query) }
    func streamCollectionChanges(query: QueryBuilder?) -> AsyncThrowingStream<CollectionChanges<T>, Error> { base.streamCollectionChanges(query: query) }
    func deleteDocument(id: String) async throws { try await base.deleteDocument(id: id) }
    func getDocuments(query: QueryBuilder) async throws -> [T] { try await base.getDocuments(query: query) }
}

@MainActor
struct FirestoreDocumentService<T: DataSyncModelProtocol>: RemoteDocumentService {

    private let base: SwiftfulDataManagersFirebase.FirebaseRemoteDocumentService<T>
    private let collectionPath: () -> String?

    init(collectionPath: @escaping () -> String?) {
        self.base = .init(collectionPath: collectionPath)
        self.collectionPath = collectionPath
    }

    func saveDocument(_ model: T) async throws {
        guard try FirestoreFieldWrite.saveReplacing(model, collectionPath: collectionPath()) else {
            return try await base.saveDocument(model)
        }
    }

    func getDocument(id: String) async throws -> T { try await base.getDocument(id: id) }
    func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws { try await base.updateDocument(id: id, data: data) }
    func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> { base.streamDocument(id: id) }
    func deleteDocument(id: String) async throws { try await base.deleteDocument(id: id) }
}
