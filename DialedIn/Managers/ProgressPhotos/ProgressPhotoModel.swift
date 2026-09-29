//
//  ProgressPhotoModel.swift
//  DialedIn
//

import Foundation

/// One progress photo: `users/{uid}/progress_photos/{id}`, with the image itself in Storage at
/// `storagePath`. Owner-only in both places.
struct ProgressPhotoModel: DataSyncModelProtocol, Hashable {
    let id: String
    let authorId: String
    let date: Date
    let pose: Pose
    /// `users/{uid}/progress_photos/{id}.jpg` in Firebase Storage.
    let storagePath: String
    /// The download URL the upload returned, or a bundled asset name for the mocks.
    let imageUrl: String?
    let weightKg: Double?
    let note: String?

    enum Pose: String, Codable, CaseIterable, Sendable {
        case front, side, back

        var title: String { rawValue.capitalized }
    }

    init(
        id: String = UUID().uuidString,
        authorId: String,
        date: Date = .now,
        pose: Pose,
        storagePath: String? = nil,
        imageUrl: String? = nil,
        weightKg: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.date = date
        self.pose = pose
        self.storagePath = storagePath ?? Self.storagePath(userId: authorId, id: id)
        self.imageUrl = imageUrl
        self.weightKg = weightKg
        self.note = note
    }

    static func storagePath(userId: String, id: String) -> String {
        "users/\(userId)/progress_photos/\(id).jpg"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case date
        case pose
        case storagePath = "storage_path"
        case imageUrl = "image_url"
        case weightKg = "weight_kg"
        case note
    }

    var eventParameters: [String: Any] {
        [
            "progress_photo_id": id,
            "progress_photo_pose": pose.rawValue
        ]
    }

    /// Two photos of the mock user a month apart, drawn from the asset catalogue.
    static var mocks: [ProgressPhotoModel] {
        let now = Date()
        return [
            ProgressPhotoModel(
                id: "progress-photo-1",
                authorId: "mock_user_123",
                date: now.addingTimeInterval(-30 * 86_400),
                pose: .front,
                imageUrl: "BarbellSquat",
                weightKg: 82.4
            ),
            ProgressPhotoModel(
                id: "progress-photo-2",
                authorId: "mock_user_123",
                date: now,
                pose: .front,
                imageUrl: "BarbellBenchPress",
                weightKg: 80.1
            )
        ]
    }
}
