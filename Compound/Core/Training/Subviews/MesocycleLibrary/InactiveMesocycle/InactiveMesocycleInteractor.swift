import SwiftUI

@MainActor
protocol InactiveMesocycleInteractor: GlobalInteractor { }

extension CoreInteractor: InactiveMesocycleInteractor { }
