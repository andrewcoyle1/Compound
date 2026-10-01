import SwiftUI

@MainActor
protocol SiriInteractor: GlobalInteractor { }

extension CoreInteractor: SiriInteractor { }
