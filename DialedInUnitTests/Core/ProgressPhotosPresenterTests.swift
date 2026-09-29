//
//  ProgressPhotosPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

private enum ProgressPhotoStubError: Error { case failed }

/// Records every upload's path, size ceiling and quality, and every delete, so the Storage side of
/// adding and removing a photo is observable.
private actor RecordingProgressPhotoUploadService: ImageUploadService {
    struct Upload: Sendable {
        let path: String
        let maxDimension: CGFloat
        let quality: CGFloat
    }

    private(set) var uploads: [Upload] = []
    private(set) var deletedPaths: [String] = []
    private let uploadError: Error?
    let url = URL(string: "https://example.com/progress.jpg")!

    init(uploadError: Error? = nil) {
        self.uploadError = uploadError
    }

    func uploadImage(image: PlatformImage, path: String, maxDimension: CGFloat, quality: CGFloat) async throws -> URL {
        uploads.append(Upload(path: path, maxDimension: maxDimension, quality: quality))
        if let uploadError { throw uploadError }
        return url
    }

    func deleteImage(path: String) async throws {
        deletedPaths.append(path)
    }
}

/// The progress photos grid: adding through the real manager and a recording upload service,
/// deleting the document and its image, and choosing the two photos to compare.
@MainActor
struct ProgressPhotosPresenterTests {

    // MARK: Doubles

    private final class Interactor: SpyGlobalInteractor, ProgressPhotosInteractor {
        let manager: ProgressPhotoManager
        var currentUser: UserModel?

        init(manager: ProgressPhotoManager) {
            self.manager = manager
        }

        var progressPhotos: [ProgressPhotoModel] { manager.photos }
        func startListeningForProgressPhotos() async { await manager.startListening(userId: "me") }
        func addProgressPhoto(image: PlatformImage, pose: ProgressPhotoModel.Pose) async throws {
            try await manager.addPhoto(image: image, userId: "me", pose: pose)
        }
        func deleteProgressPhoto(_ photo: ProgressPhotoModel) async throws {
            try await manager.deletePhoto(photo)
        }
    }

    private final class Router: ProgressPhotosRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var compared: [ProgressPhotoCompareDelegate] = []
        private(set) var alertTitles: [String] = []
        func showDevSettingsView() { }
        func showProgressPhotoCompareView(delegate: ProgressPhotoCompareDelegate) { compared.append(delegate) }
        func showAlert(error: Error) { alertTitles.append("Error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: ProgressPhotosPresenter
        let router: Router
        let service: RecordingProgressPhotoUploadService
    }

    private func makeScreen(
        photos: [ProgressPhotoModel] = [],
        service: RecordingProgressPhotoUploadService = RecordingProgressPhotoUploadService()
    ) async -> Screen {
        let manager = ProgressPhotoManager(
            syncEngine: TestManagers.collectionEngine(photos, key: "progress-photos"),
            imageUploadManager: ImageUploadManager(service: service)
        )
        let router = Router()
        let presenter = ProgressPhotosPresenter(interactor: Interactor(manager: manager), router: router)
        await presenter.onViewAppear()
        return Screen(presenter: presenter, router: router, service: service)
    }

    private func photo(_ id: String, daysAgo: Double, author: String = "me") -> ProgressPhotoModel {
        ProgressPhotoModel(id: id, authorId: author, date: Date().addingTimeInterval(-daysAgo * 86_400), pose: .front)
    }

    private var image: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
    }

    // MARK: Add

    @Test("Test Adding Uploads At 1600pt JPEG 0.8 To The Owner's Path And Saves The Photo")
    func testAddUploadsAndSaves() async {
        let screen = await makeScreen()

        screen.presenter.onImagePicked(image)
        #expect(screen.presenter.isPoseDialogPresented)

        await screen.presenter.onPoseSelected(.side)

        let uploads = await screen.service.uploads
        #expect(uploads.count == 1)
        let upload = uploads.first
        #expect(upload?.path.hasPrefix("users/me/progress_photos/") == true)
        #expect(upload?.path.hasSuffix(".jpg") == true)
        #expect(upload?.maxDimension == 1600)
        #expect(upload?.quality == 0.8)
        #expect(screen.presenter.pendingImage == nil)
        #expect(!screen.presenter.isUploading)

        let saved = await TestManagers.eventually { screen.presenter.photos.count == 1 }
        #expect(saved)
        let photo = screen.presenter.photos.first
        #expect(photo?.pose == .side)
        #expect(photo?.authorId == "me")
        #expect(photo?.storagePath == upload?.path)
        #expect(photo?.imageUrl == "https://example.com/progress.jpg")
        #expect(screen.router.alertTitles.isEmpty)
    }

    @Test("Test A Failed Upload Alerts And Saves Nothing")
    func testFailedUploadAlerts() async {
        let screen = await makeScreen(service: RecordingProgressPhotoUploadService(uploadError: ProgressPhotoStubError.failed))

        screen.presenter.onImagePicked(image)
        await screen.presenter.onPoseSelected(.front)

        #expect(screen.router.alertTitles == ["Error"])
        #expect(screen.presenter.photos.isEmpty)
    }

    @Test("Test The Camera Asks For The Pose Only Once Its Cover Has Gone")
    func testCameraAsksForPoseAfterDismiss() async {
        let screen = await makeScreen()

        screen.presenter.onCameraDismissed()
        #expect(!screen.presenter.isPoseDialogPresented, "cancelled camera asks nothing")

        screen.presenter.onCameraImagePicked(image)
        #expect(!screen.presenter.isPoseDialogPresented)
        screen.presenter.onCameraDismissed()
        #expect(screen.presenter.isPoseDialogPresented)
    }

    // MARK: Delete

    @Test("Test Deleting Removes The Document, Its Image And Its Selection")
    func testDeleteRemovesDocumentAndImage() async {
        let older = photo("old", daysAgo: 10)
        let newer = photo("new", daysAgo: 1)
        let screen = await makeScreen(photos: [older, newer, photo("theirs", daysAgo: 2, author: "someone")])
        #expect(await TestManagers.eventually { screen.presenter.photos.count == 2 }, "another author's photo is hidden")

        screen.presenter.onPhotoPressed(newer)
        screen.presenter.onDeletePressed(newer)
        #expect(screen.presenter.photoPendingDelete == newer)

        await screen.presenter.onDeleteConfirmed()

        #expect(screen.presenter.photoPendingDelete == nil)
        #expect(screen.presenter.selectedIds.isEmpty)
        #expect(await screen.service.deletedPaths == ["users/me/progress_photos/new.jpg"])
        #expect(await TestManagers.eventually { screen.presenter.photos.map(\.id) == ["old"] })
    }

    // MARK: Compare

    @Test("Test Selection Keeps The Last Two Tapped And Toggles Off")
    func testSelectionKeepsLastTwo() async {
        let first = photo("a", daysAgo: 30)
        let second = photo("b", daysAgo: 20)
        let third = photo("c", daysAgo: 10)
        let screen = await makeScreen(photos: [first, second, third])

        screen.presenter.onPhotoPressed(first)
        #expect(!screen.presenter.canCompare)
        screen.presenter.onPhotoPressed(second)
        #expect(screen.presenter.canCompare)

        screen.presenter.onPhotoPressed(third)
        #expect(screen.presenter.selectedIds == ["b", "c"])

        screen.presenter.onPhotoPressed(second)
        #expect(screen.presenter.selectedIds == ["c"])
        #expect(!screen.presenter.canCompare)
    }

    @Test("Test Compare Puts The Older Photo First Whatever The Tap Order")
    func testCompareOrdersByDate() async {
        let older = photo("old", daysAgo: 30)
        let newer = photo("new", daysAgo: 1)
        let screen = await makeScreen(photos: [older, newer])
        #expect(await TestManagers.eventually { screen.presenter.photos.count == 2 })

        screen.presenter.onComparePressed()
        #expect(screen.router.compared.isEmpty, "nothing selected, nothing shown")

        screen.presenter.onPhotoPressed(newer)
        screen.presenter.onPhotoPressed(older)
        screen.presenter.onComparePressed()

        #expect(screen.router.compared.count == 1)
        #expect(screen.router.compared.first?.before.id == "old")
        #expect(screen.router.compared.first?.after.id == "new")
    }

    @Test("Test Sections Group By Day, Newest First")
    func testSectionsGroupByDay() async {
        let screen = await makeScreen(photos: [photo("a", daysAgo: 5), photo("b", daysAgo: 0), photo("c", daysAgo: 5.001)])
        #expect(await TestManagers.eventually { screen.presenter.photos.count == 3 })
        let days = screen.presenter.sections.map(\.date)
        #expect(days == days.sorted(by: >))
        #expect(screen.presenter.sections.first?.photos.map(\.id) == ["b"])
    }
}
