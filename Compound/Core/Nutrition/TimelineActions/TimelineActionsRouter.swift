import SwiftUI

@MainActor
protocol TimelineActionsRouter: GlobalRouter { }

extension CoreRouter: TimelineActionsRouter { }
