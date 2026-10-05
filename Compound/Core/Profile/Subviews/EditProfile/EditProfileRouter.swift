import SwiftUI

@MainActor
protocol EditProfileRouter: GlobalRouter {
    func showEditUsernameView()
}

extension CoreRouter: EditProfileRouter { }
