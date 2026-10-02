import SwiftUI

@MainActor
protocol MealDescribeInteractor: GlobalInteractor {
    func describeMeal(text: String) async throws -> String
}

extension CoreInteractor: MealDescribeInteractor { }
