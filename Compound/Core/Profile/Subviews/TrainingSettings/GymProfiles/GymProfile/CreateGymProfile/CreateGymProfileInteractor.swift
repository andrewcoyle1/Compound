import SwiftUI

@MainActor
protocol CreateGymProfileInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }
}

extension CoreInteractor: CreateGymProfileInteractor { }
