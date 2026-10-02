import SwiftUI

@MainActor
protocol SetTargetInteractor: GlobalInteractor { }

extension CoreInteractor: SetTargetInteractor { }
