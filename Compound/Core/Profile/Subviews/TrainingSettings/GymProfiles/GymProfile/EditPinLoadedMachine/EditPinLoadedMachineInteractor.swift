import SwiftUI

@MainActor
protocol EditPinLoadedMachineInteractor: GlobalInteractor { }

extension CoreInteractor: EditPinLoadedMachineInteractor { }
