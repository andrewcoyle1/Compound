import SwiftUI

@MainActor
protocol MuscleBalanceRouter: GlobalRouter { }

extension CoreRouter: MuscleBalanceRouter { }
