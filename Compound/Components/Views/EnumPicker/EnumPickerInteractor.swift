import SwiftUI

@MainActor
protocol EnumPickerInteractor: GlobalInteractor { }

extension CoreInteractor: EnumPickerInteractor { }
