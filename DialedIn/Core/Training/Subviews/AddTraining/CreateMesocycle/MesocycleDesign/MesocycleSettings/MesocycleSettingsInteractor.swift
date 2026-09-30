import SwiftUI

@MainActor
protocol MesocycleSettingsInteractor: GlobalInteractor {
    func saveMesocycle(mesocycle: Mesocycle) async throws
    func setActiveMesocycle(mesocycleId: String) async throws
}

extension CoreInteractor: MesocycleSettingsInteractor { }
