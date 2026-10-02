import SwiftUI

@MainActor
protocol AddFixedWeightBarInteractor: GlobalInteractor { }

extension CoreInteractor: AddFixedWeightBarInteractor { }
