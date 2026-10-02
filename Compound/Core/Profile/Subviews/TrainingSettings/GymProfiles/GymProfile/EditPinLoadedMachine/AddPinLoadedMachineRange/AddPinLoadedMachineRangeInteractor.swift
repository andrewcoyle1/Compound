import SwiftUI

@MainActor
protocol AddPinLoadedMachineRangeInteractor: GlobalInteractor { }

extension CoreInteractor: AddPinLoadedMachineRangeInteractor { }
