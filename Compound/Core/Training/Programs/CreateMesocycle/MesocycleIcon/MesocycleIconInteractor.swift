import SwiftUI

@MainActor
protocol MesocycleIconInteractor: GlobalInteractor {
    var userId: String? { get }
}

extension CoreInteractor: MesocycleIconInteractor { }
