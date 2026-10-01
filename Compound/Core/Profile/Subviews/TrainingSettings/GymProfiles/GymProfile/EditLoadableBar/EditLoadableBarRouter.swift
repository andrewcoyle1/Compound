import SwiftUI

@MainActor
protocol EditLoadableBarRouter: GlobalRouter {
    func showAddLoadableBarView(delegate: AddLoadableBarDelegate)
}

extension CoreRouter: EditLoadableBarRouter { }
