import SwiftUI

@MainActor
protocol LicencesInteractor: GlobalInteractor { }

extension CoreInteractor: LicencesInteractor { }
