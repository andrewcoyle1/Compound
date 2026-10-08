import SwiftUI

@MainActor
protocol EditStackMachineInteractor: GlobalInteractor { }

extension CoreInteractor: EditStackMachineInteractor { }
