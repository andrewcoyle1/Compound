import SwiftUI

@MainActor
protocol AddBandInteractor: GlobalInteractor { }

extension CoreInteractor: AddBandInteractor { }
