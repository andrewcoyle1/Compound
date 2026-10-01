import SwiftUI

@MainActor
protocol EditFreeWeightInteractor: GlobalInteractor { }

extension CoreInteractor: EditFreeWeightInteractor { }
