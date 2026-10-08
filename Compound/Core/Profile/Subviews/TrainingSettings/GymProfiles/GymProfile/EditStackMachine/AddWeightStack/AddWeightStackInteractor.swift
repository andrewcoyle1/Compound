import SwiftUI

@MainActor
protocol AddWeightStackInteractor: GlobalInteractor { }

extension CoreInteractor: AddWeightStackInteractor { }
