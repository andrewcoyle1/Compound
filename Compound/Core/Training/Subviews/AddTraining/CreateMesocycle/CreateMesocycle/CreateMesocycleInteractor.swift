import SwiftUI

@MainActor
protocol CreateMesocycleInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var prebuiltMesocycles: [Mesocycle] { get }
}

extension CoreInteractor: CreateMesocycleInteractor { }
