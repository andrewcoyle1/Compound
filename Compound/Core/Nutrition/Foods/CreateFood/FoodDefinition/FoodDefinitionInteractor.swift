import SwiftUI

@MainActor
protocol FoodDefinitionInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws
}

extension CoreInteractor: FoodDefinitionInteractor { }
