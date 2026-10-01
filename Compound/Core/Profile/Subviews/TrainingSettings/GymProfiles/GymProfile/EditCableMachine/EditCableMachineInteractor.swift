import SwiftUI

@MainActor
protocol EditCableMachineInteractor: GlobalInteractor { }

extension CoreInteractor: EditCableMachineInteractor { }
