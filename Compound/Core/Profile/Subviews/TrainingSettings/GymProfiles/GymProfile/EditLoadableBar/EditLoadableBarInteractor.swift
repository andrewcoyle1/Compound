import SwiftUI

@MainActor
protocol EditLoadableBarInteractor: GlobalInteractor { }

extension CoreInteractor: EditLoadableBarInteractor { }
