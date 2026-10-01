import SwiftUI

@MainActor
protocol LegalInteractor: GlobalInteractor { }

extension CoreInteractor: LegalInteractor { }
