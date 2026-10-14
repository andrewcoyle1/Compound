import SwiftUI

@MainActor
protocol NameMesocycleInteractor: GlobalInteractor { }

extension CoreInteractor: NameMesocycleInteractor { }
