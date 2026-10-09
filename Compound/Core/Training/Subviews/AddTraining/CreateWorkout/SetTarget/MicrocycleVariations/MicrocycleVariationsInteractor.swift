import SwiftUI

@MainActor
protocol MicrocycleVariationsInteractor: GlobalInteractor { }

extension CoreInteractor: MicrocycleVariationsInteractor { }
