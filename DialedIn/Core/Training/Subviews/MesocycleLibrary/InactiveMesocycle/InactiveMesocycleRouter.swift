import SwiftUI

@MainActor
protocol InactiveMesocycleRouter: GlobalRouter { }

extension CoreRouter: InactiveMesocycleRouter { }
