import SwiftUI

@MainActor
protocol EditBandInteractor: GlobalInteractor { }

extension CoreInteractor: EditBandInteractor { }
