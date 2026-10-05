import SwiftUI
import PhotosUI

struct ProgressPhotoSection: Identifiable {
    let date: Date
    let photos: [ProgressPhotoModel]
    var id: Date { date }
}

@Observable
@MainActor
class ProgressPhotosPresenter {

    private let interactor: ProgressPhotosInteractor
    private let router: ProgressPhotosRouter

    /// In the order they were tapped; at most two.
    private(set) var selectedIds: [String] = []
    private(set) var isUploading = false
    private(set) var pendingImage: PlatformImage?
    var isCameraPresented = false
    var isLibraryPresented = false
    var isPoseDialogPresented = false
    var libraryItem: PhotosPickerItem?
    var photoPendingDelete: ProgressPhotoModel?

    init(interactor: ProgressPhotosInteractor, router: ProgressPhotosRouter) {
        self.interactor = interactor
        self.router = router
    }

    var photos: [ProgressPhotoModel] {
        interactor.progressPhotos
    }

    /// One section per day, newest first.
    var sections: [ProgressPhotoSection] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: photos) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted(by: >).map { day in
            ProgressPhotoSection(date: day, photos: byDay[day, default: []].sorted { $0.date > $1.date })
        }
    }

    var canCompare: Bool {
        selectedIds.count == 2
    }

    func isSelected(_ photo: ProgressPhotoModel) -> Bool {
        selectedIds.contains(photo.id)
    }

    func caption(for photo: ProgressPhotoModel) -> String {
        let date = photo.date.formatted(date: .abbreviated, time: .omitted)
        guard let weightKg = photo.weightKg else { return date }
        let unit = interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
        let weight = UnitConversion.convertWeight(weightKg, to: unit).formatted(.number.precision(.fractionLength(1)))
        return "\(date) · \(weight) \(unit.abbreviation)"
    }

    // MARK: Lifecycle

    func onViewAppear() async {
        interactor.trackScreenEvent(event: Event.onAppear)
        await interactor.startListeningForProgressPhotos()
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    // MARK: Add

    /// The pose the camera was opened for. Chosen before the shutter, so a camera photo saves as
    /// soon as the camera closes; only a library photo is asked which pose it is.
    private(set) var cameraPose: ProgressPhotoModel.Pose?

    func onCameraPressed(pose: ProgressPhotoModel.Pose) {
        cameraPose = pose
        isCameraPresented = true
    }

    func onLibraryPressed() {
        isLibraryPresented = true
    }

    func onLibraryItemChanged() async {
        guard let item = libraryItem else { return }
        libraryItem = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = PlatformImage(data: data) else {
                throw AppError("That photo could not be loaded.")
            }
            onImagePicked(image)
        } catch {
            interactor.trackEvent(event: Event.loadLibraryPhotoFail(error: error))
            router.showAlert(title: String(localized: "Unable to Load Photo"), error: error)
        }
    }

    /// The pose is asked for once the image is in hand.
    func onImagePicked(_ image: PlatformImage) {
        pendingImage = image
        isPoseDialogPresented = true
    }

    /// The camera hands its image over while its cover is still up, so the upload waits for the
    /// cover to go and the progress overlay is not hidden behind it.
    func onCameraImagePicked(_ image: PlatformImage) {
        pendingImage = image
    }

    func onCameraDismissed() async {
        let pose = cameraPose
        cameraPose = nil
        guard pendingImage != nil else { return }
        if let pose {
            await onPoseSelected(pose)
        } else {
            isPoseDialogPresented = true
        }
    }

    func onPoseCancelled() {
        pendingImage = nil
    }

    func onPoseSelected(_ pose: ProgressPhotoModel.Pose) async {
        guard let image = pendingImage else { return }
        pendingImage = nil
        isUploading = true
        defer { isUploading = false }
        interactor.trackEvent(event: Event.addStart(pose: pose))
        do {
            try await interactor.addProgressPhoto(image: image, pose: pose)
            interactor.trackEvent(event: Event.addSuccess(pose: pose))
        } catch {
            interactor.trackEvent(event: Event.addFail(error: error))
            router.showAlert(title: String(localized: "Unable to Add Photo"), error: error)
        }
    }

    // MARK: Select and compare

    /// Toggles the photo. A third selection drops the earliest one, so two are always the latest
    /// two tapped.
    func onPhotoPressed(_ photo: ProgressPhotoModel) {
        if let index = selectedIds.firstIndex(of: photo.id) {
            selectedIds.remove(at: index)
            return
        }
        selectedIds.append(photo.id)
        if selectedIds.count > 2 {
            selectedIds.removeFirst()
        }
    }

    /// Older photo on the left, newer on the right, whichever order they were tapped in.
    func onComparePressed() {
        let chosen = photos.filter { selectedIds.contains($0.id) }.sorted { $0.date < $1.date }
        guard chosen.count == 2 else { return }
        interactor.trackEvent(event: Event.compare)
        router.showProgressPhotoCompareView(
            delegate: ProgressPhotoCompareDelegate(
                before: chosen[0],
                after: chosen[1],
                beforeCaption: caption(for: chosen[0]),
                afterCaption: caption(for: chosen[1])
            )
        )
    }

    // MARK: Delete

    /// Delete used to live only in the photo's context menu, which the HIG asks not to rely on —
    /// tapping a single photo to select it now also enables this toolbar action for it.
    var selectedPhotoForDelete: ProgressPhotoModel? {
        guard selectedIds.count == 1 else { return nil }
        return photos.first { $0.id == selectedIds[0] }
    }

    func onDeleteToolbarPressed() {
        guard let photo = selectedPhotoForDelete else { return }
        onDeletePressed(photo)
    }

    func onDeletePressed(_ photo: ProgressPhotoModel) {
        photoPendingDelete = photo
    }

    func onDeleteConfirmed() async {
        guard let photo = photoPendingDelete else { return }
        photoPendingDelete = nil
        selectedIds.removeAll { $0 == photo.id }
        interactor.trackEvent(event: Event.deleteStart)
        do {
            try await interactor.deleteProgressPhoto(photo)
            interactor.trackEvent(event: Event.deleteSuccess)
        } catch {
            interactor.trackEvent(event: Event.deleteFail(error: error))
            router.showAlert(title: String(localized: "Unable to Delete Photo"), error: error)
        }
    }
}

extension ProgressPhotosPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadLibraryPhotoFail(error: Error)
        case addStart(pose: ProgressPhotoModel.Pose)
        case addSuccess(pose: ProgressPhotoModel.Pose)
        case addFail(error: Error)
        case compare
        case deleteStart
        case deleteSuccess
        case deleteFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:      return "ProgressPhotosView_Appear"
            case .onDisappear:   return "ProgressPhotosView_Disappear"
            case .loadLibraryPhotoFail: return "ProgressPhotosView_LoadLibraryPhoto_Fail"
            case .addStart:      return "ProgressPhotosView_Add_Start"
            case .addSuccess:    return "ProgressPhotosView_Add_Success"
            case .addFail:       return "ProgressPhotosView_Add_Fail"
            case .compare:       return "ProgressPhotosView_Compare"
            case .deleteStart:   return "ProgressPhotosView_Delete_Start"
            case .deleteSuccess: return "ProgressPhotosView_Delete_Success"
            case .deleteFail:    return "ProgressPhotosView_Delete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .addStart(let pose), .addSuccess(let pose):
                return ["pose": pose.rawValue]
            case .addFail(let error), .deleteFail(let error), .loadLibraryPhotoFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .addFail, .deleteFail, .loadLibraryPhotoFail: return .severe
            default:                    return .analytic
            }
        }
    }
}
