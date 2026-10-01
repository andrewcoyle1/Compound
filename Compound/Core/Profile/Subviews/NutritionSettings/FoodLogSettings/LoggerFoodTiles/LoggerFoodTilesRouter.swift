import SwiftUI

@MainActor
protocol LoggerFoodTilesRouter: GlobalRouter { }

extension CoreRouter: LoggerFoodTilesRouter { }
