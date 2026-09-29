//
//  ProgressPhotoManager.swift
//  DialedIn
//

import Foundation

/// The signed-in user's progress photos, mirrored from `users/{uid}/progress_photos`.
///
/// ponytail: listening starts when the photos screen opens rather than in `CoreInteractor.logIn`,
/// which keeps this feature out of that shared function. Switching account restarts it; move the
/// call into `logIn` if another screen needs the photos before this one has opened.
@Observable
@MainActor
final class ProgressPhotoManager {

    /// Photos are compared side by side, so they keep more detail than the 1280pt default.
    static let maxDimension: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.8

    private let syncEngine: CollectionSyncEngine<ProgressPhotoModel>
    private let imageUploadManager: ImageUploadManager
    private(set) var userId: String?

    /// Newest first, and only the listening account's.
    var photos: [ProgressPhotoModel] {
        guard let userId else { return [] }
        return syncEngine.currentCollection
            .filter { $0.authorId == userId }
            .sorted { $0.date > $1.date }
    }

    init(syncEngine: CollectionSyncEngine<ProgressPhotoModel>, imageUploadManager: ImageUploadManager) {
        self.syncEngine = syncEngine
        self.imageUploadManager = imageUploadManager
    }

    func startListening(userId: String) async {
        if self.userId != userId {
            syncEngine.stopListening()
            self.userId = userId
        }
        await syncEngine.startListening()
    }

    /// Sign-out and account deletion: the listener's path is the signed-in user's, so it must not
    /// outlive them.
    func stopListening() {
        syncEngine.stopListening()
        userId = nil
    }

    /// Uploads the image, then saves the document that points at it. A failed save removes the
    /// uploaded image so it is not left orphaned in Storage.
    @discardableResult
    func addPhoto(
        image: PlatformImage,
        userId: String,
        pose: ProgressPhotoModel.Pose,
        date: Date = .now,
        weightKg: Double? = nil,
        note: String? = nil
    ) async throws -> ProgressPhotoModel {
        let id = UUID().uuidString
        let path = ProgressPhotoModel.storagePath(userId: userId, id: id)
        let url = try await imageUploadManager.uploadImage(
            image: image,
            path: path,
            maxDimension: Self.maxDimension,
            quality: Self.jpegQuality
        )
        let photo = ProgressPhotoModel(
            id: id,
            authorId: userId,
            date: date,
            pose: pose,
            storagePath: path,
            imageUrl: url.absoluteString,
            weightKg: weightKg,
            note: note
        )
        do {
            try await syncEngine.saveDocument(photo)
        } catch {
            try? await imageUploadManager.deleteImage(path: path)
            throw error
        }
        return photo
    }

    /// Deletes the document first, so a photo never shows without its image. A failed image
    /// delete leaves an unreferenced file, which is harmless and not worth failing over.
    func deletePhoto(_ photo: ProgressPhotoModel) async throws {
        try await syncEngine.deleteDocument(id: photo.id)
        try? await imageUploadManager.deleteImage(path: photo.storagePath)
    }
}
