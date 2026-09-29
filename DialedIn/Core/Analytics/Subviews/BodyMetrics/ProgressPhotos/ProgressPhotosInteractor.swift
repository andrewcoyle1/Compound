import SwiftUI

@MainActor
protocol ProgressPhotosInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var progressPhotos: [ProgressPhotoModel] { get }
    func startListeningForProgressPhotos() async
    func addProgressPhoto(image: PlatformImage, pose: ProgressPhotoModel.Pose) async throws
    func deleteProgressPhoto(_ photo: ProgressPhotoModel) async throws
}

extension CoreInteractor: ProgressPhotosInteractor { }
