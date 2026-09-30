import SwiftUI

@MainActor
protocol CreateMesocycleInteractor: GlobalInteractor { }

extension CoreInteractor: CreateMesocycleInteractor { }
