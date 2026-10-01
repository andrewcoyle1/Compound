import SwiftUI

@MainActor
protocol LoggerBannerRouter: GlobalRouter { }

extension CoreRouter: LoggerBannerRouter { }
