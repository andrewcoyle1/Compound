import SwiftUI

@MainActor
protocol MuscleGroupPickerInteractor: GlobalInteractor { }

extension CoreInteractor: MuscleGroupPickerInteractor { }
