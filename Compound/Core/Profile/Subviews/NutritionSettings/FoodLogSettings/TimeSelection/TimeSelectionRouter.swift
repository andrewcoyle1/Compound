import SwiftUI

@MainActor
protocol TimeSelectionRouter: GlobalRouter { }

extension CoreRouter: TimeSelectionRouter { }
