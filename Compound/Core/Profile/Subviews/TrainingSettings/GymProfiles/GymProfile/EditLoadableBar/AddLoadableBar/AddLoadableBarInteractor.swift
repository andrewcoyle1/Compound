import SwiftUI

@MainActor
protocol AddLoadableBarInteractor: GlobalInteractor { }

extension CoreInteractor: AddLoadableBarInteractor { }
