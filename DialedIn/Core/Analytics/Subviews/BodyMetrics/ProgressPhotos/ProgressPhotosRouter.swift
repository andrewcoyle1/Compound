import SwiftUI

@MainActor
protocol ProgressPhotosRouter: GlobalRouter {
    func showProgressPhotoCompareView(delegate: ProgressPhotoCompareDelegate)
}

extension CoreRouter: ProgressPhotosRouter { }
