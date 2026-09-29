import SwiftUI

@MainActor
protocol AccountInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentUser: UserModel? { get }
    func signOut() async throws
    func deleteUserProfile()
    func deleteAccount() async throws
    func updateProfileImageUrl(image: PlatformImage) async throws
    func updateUser(data: [String: any DMCodableSendable]) async throws
    func updatePrivacy(isPrivate: Bool) async throws
}

extension CoreInteractor: AccountInteractor { }
