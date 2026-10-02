import SwiftUI

@MainActor
protocol AboutRouter: GlobalRouter {
    func showLicencesView(delegate: LicencesDelegate)
}

extension CoreRouter: AboutRouter { }
