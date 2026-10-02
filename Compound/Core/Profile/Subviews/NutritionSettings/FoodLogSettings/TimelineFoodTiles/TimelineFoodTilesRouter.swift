import SwiftUI

@MainActor
protocol TimelineFoodTilesRouter: GlobalRouter { }

extension CoreRouter: TimelineFoodTilesRouter { }
