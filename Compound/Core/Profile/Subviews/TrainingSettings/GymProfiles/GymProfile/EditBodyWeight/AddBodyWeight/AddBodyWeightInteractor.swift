import SwiftUI

@MainActor
protocol AddBodyWeightInteractor: GlobalInteractor { }

extension CoreInteractor: AddBodyWeightInteractor { }
