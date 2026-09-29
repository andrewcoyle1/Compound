//
//  ImageUploadManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

private enum ImageUploadStubError: Error { case failed }

/// An `ImageUploadService` that records the paths it was given and can be made to fail, so the
/// storage path — the one thing the caller controls and the only thing that makes an upload
/// overwrite or orphan a file — is observable.
private actor ImageUploadRecordingService: ImageUploadService {
    private(set) var uploadedPaths: [String] = []
    private(set) var uploadedSizes: [CGSize] = []
    private(set) var deletedPaths: [String] = []

    private let uploadError: Error?
    private let deleteError: Error?
    private let url: URL

    init(
        url: URL = URL(string: "https://example.com/recorded.png")!,
        uploadError: Error? = nil,
        deleteError: Error? = nil
    ) {
        self.url = url
        self.uploadError = uploadError
        self.deleteError = deleteError
    }

    func uploadImage(image: PlatformImage, path: String, maxDimension: CGFloat, quality: CGFloat) async throws -> URL {
        uploadedPaths.append(path)
        uploadedSizes.append(image.size)
        if let uploadError { throw uploadError }
        return url
    }

    func deleteImage(path: String) async throws {
        deletedPaths.append(path)
        if let deleteError { throw deleteError }
    }
}

/// Profile pictures, food photos and exercise thumbnails all go through this one manager.
///
/// It forwards and nothing else, so what matters is that the two arguments arrive intact. The
/// path is the storage key: a path the manager altered would either overwrite somebody else's
/// image or leave the uploaded one unreferenced, and both failures are silent — the URL still
/// comes back and the caller still saves it.
///
/// `FirebaseImageUploadService` is not covered here; it resolves `Storage.storage()` at call time
/// and cannot run without a configured Firebase app.
@MainActor
struct ImageUploadManagerTests {

    private var image: PlatformImage {
        UIImage(systemName: "star.fill")!
    }

    // MARK: - Uploading

    @Test("Test Uploading Returns The URL The Service Answered With")
    func testUploadingReturnsTheServicesURL() async throws {
        let manager = ImageUploadManager(service: MockImageUploadService())

        let url = try await manager.uploadImage(image: image, path: "users/user-1/profile.png")

        #expect(url == URL(string: "https://example.com/image.png"))
    }

    /// The path is the storage key. It is built by the caller — `users/<uid>/...` — and has to
    /// arrive exactly as given, or the saved URL points somewhere the image is not.
    @Test("Test The Path And Image Reach The Service Unchanged")
    func testThePathAndImageReachTheServiceUnchanged() async throws {
        let service = ImageUploadRecordingService()
        let manager = ImageUploadManager(service: service)

        _ = try await manager.uploadImage(image: image, path: "users/user-1/profile.png")

        let paths = await service.uploadedPaths
        let sizes = await service.uploadedSizes
        #expect(paths == ["users/user-1/profile.png"])
        #expect(sizes.first == image.size)
    }

    /// Two uploads in a row must not share a path — several screens upload while another is still
    /// in flight, and a manager holding onto the last one would overwrite it.
    @Test("Test Each Upload Keeps Its Own Path")
    func testEachUploadKeepsItsOwnPath() async throws {
        let service = ImageUploadRecordingService()
        let manager = ImageUploadManager(service: service)

        _ = try await manager.uploadImage(image: image, path: "users/user-1/profile.png")
        _ = try await manager.uploadImage(image: image, path: "foods/food-2/photo.png")

        let paths = await service.uploadedPaths
        #expect(paths == ["users/user-1/profile.png", "foods/food-2/photo.png"])
    }

    // MARK: - Deleting

    @Test("Test Deleting Passes The Path Through")
    func testDeletingPassesThePathThrough() async throws {
        let service = ImageUploadRecordingService()
        let manager = ImageUploadManager(service: service)

        try await manager.deleteImage(path: "users/user-1/profile.png")

        let paths = await service.deletedPaths
        #expect(paths == ["users/user-1/profile.png"])
    }

    // MARK: - Errors

    /// The caller saves the returned URL onto a profile or a food, so a failed upload has to throw
    /// rather than answer a URL — a saved link to a file that was never written shows as a broken
    /// image forever.
    @Test("Test A Failed Upload Throws Rather Than Answering A URL")
    func testFailedUploadThrows() async {
        let service = ImageUploadRecordingService(uploadError: ImageUploadStubError.failed)
        let manager = ImageUploadManager(service: service)
        let star = image

        await #expect(throws: ImageUploadStubError.self) {
            _ = try await manager.uploadImage(image: star, path: "users/user-1/profile.png")
        }
    }

    /// Deletion failures matter for the opposite reason: a caller that clears the stored URL on a
    /// delete it believes succeeded leaves the file behind with nothing referring to it.
    @Test("Test A Failed Delete Throws")
    func testFailedDeleteThrows() async {
        let service = ImageUploadRecordingService(deleteError: ImageUploadStubError.failed)
        let manager = ImageUploadManager(service: service)

        await #expect(throws: ImageUploadStubError.self) {
            try await manager.deleteImage(path: "users/user-1/profile.png")
        }
    }

    /// The mock never fails, which is what makes previews and the mock build usable — pinned so a
    /// change to it shows up as a failure here rather than as a preview that suddenly throws.
    @Test("Test The Mock Service Deletes Without Throwing")
    func testMockServiceDeletesWithoutThrowing() async throws {
        let manager = ImageUploadManager(service: MockImageUploadService())

        try await manager.deleteImage(path: "users/user-1/profile.png")
    }
}
