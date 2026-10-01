import SwiftUI

@MainActor
protocol AppIconInteractor: GlobalInteractor { }

extension CoreInteractor: AppIconInteractor { }
