import SwiftUI

@MainActor
protocol WeeklyReviewRouter: ShareSheetRouter, AskCoachRouter { }

extension CoreRouter: WeeklyReviewRouter { }
