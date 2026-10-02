import SwiftUI

@MainActor
protocol FoodPackagingInteractor: GlobalInteractor {
    
}

extension CoreInteractor: FoodPackagingInteractor { }
