import SwiftUI

@MainActor
protocol AddWeightStackRouter: GlobalRouter { }

extension CoreRouter: AddWeightStackRouter { }
