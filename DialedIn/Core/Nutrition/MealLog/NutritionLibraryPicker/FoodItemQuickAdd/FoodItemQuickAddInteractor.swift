import SwiftUI

@MainActor
protocol FoodItemQuickAddInteractor: GlobalInteractor { }

extension CoreInteractor: FoodItemQuickAddInteractor { }
