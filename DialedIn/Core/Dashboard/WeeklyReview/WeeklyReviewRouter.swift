import SwiftUI

@MainActor
protocol WeeklyReviewRouter: ShareSheetRouter { }

extension CoreRouter: WeeklyReviewRouter { }
