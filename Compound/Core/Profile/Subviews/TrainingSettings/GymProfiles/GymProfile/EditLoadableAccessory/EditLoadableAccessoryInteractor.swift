import SwiftUI

@MainActor
protocol EditLoadableAccessoryInteractor: GlobalInteractor { }

extension CoreInteractor: EditLoadableAccessoryInteractor { }
