import SwiftUI

@MainActor
protocol EditUsernameInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func isUsernameAvailable(_ handle: String) async throws -> Bool
    func claimUsername(_ handle: String) async throws
}

extension CoreInteractor: EditUsernameInteractor { }
