import SwiftUI

@MainActor
protocol AddGymMachineInteractor: GlobalInteractor { }

extension CoreInteractor: AddGymMachineInteractor { }
