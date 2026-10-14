import SwiftUI

@MainActor
protocol EquipmentPickerInteractor: GlobalInteractor { }

extension CoreInteractor: EquipmentPickerInteractor { }
