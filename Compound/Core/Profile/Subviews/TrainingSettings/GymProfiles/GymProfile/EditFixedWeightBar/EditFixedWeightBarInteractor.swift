import SwiftUI

@MainActor
protocol EditFixedWeightBarInteractor: GlobalInteractor { }

extension CoreInteractor: EditFixedWeightBarInteractor { }
