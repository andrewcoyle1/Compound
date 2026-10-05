import SwiftUI

@MainActor
protocol EditProfileInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func updateProfileImageUrl(image: PlatformImage) async throws
    func updateUser(data: [String: any DMCodableSendable]) async throws
    func updatePrivacy(isPrivate: Bool) async throws
}

extension CoreInteractor: EditProfileInteractor { }
