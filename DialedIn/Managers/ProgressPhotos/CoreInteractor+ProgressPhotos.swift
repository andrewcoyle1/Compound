//
//  CoreInteractor+ProgressPhotos.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    /// The signed-in user's progress photos, newest first.
    var progressPhotos: [ProgressPhotoModel] {
        guard let userId, progressPhotoManager.userId == userId else { return [] }
        return progressPhotoManager.photos
    }

    func startListeningForProgressPhotos() async {
        guard let userId else { return }
        await progressPhotoManager.startListening(userId: userId)
    }

    /// Taken now, carrying the most recent logged scale weight.
    func addProgressPhoto(image: PlatformImage, pose: ProgressPhotoModel.Pose) async throws {
        guard let userId else { throw AppError("Not signed in.") }
        let latestWeight = bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .max { $0.date < $1.date }?
            .weightKg
        try await progressPhotoManager.addPhoto(image: image, userId: userId, pose: pose, weightKg: latestWeight)
    }

    func deleteProgressPhoto(_ photo: ProgressPhotoModel) async throws {
        try await progressPhotoManager.deletePhoto(photo)
    }
}
