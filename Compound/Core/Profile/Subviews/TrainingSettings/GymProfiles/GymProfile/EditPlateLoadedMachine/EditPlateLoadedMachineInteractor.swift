import SwiftUI

@MainActor
protocol EditPlateLoadedMachineInteractor: GlobalInteractor { }

extension CoreInteractor: EditPlateLoadedMachineInteractor { }
