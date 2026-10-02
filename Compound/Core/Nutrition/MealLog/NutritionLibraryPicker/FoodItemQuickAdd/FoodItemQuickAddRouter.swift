import SwiftUI

@MainActor
protocol FoodItemQuickAddRouter: GlobalRouter { }

extension CoreRouter: FoodItemQuickAddRouter { }
