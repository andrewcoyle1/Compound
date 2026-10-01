import SwiftUI

@MainActor
protocol AddFreeWeightInteractor: GlobalInteractor { }

extension CoreInteractor: AddFreeWeightInteractor { }
