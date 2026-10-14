import SwiftUI

@MainActor
protocol SetTrackerRowRouter: GlobalRouter {
    func showRestModal(
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonAction: @escaping () -> Void,
        minutesSelection: Binding<Int>,
        secondsSelection: Binding<Int>
    )
    func showPlateCalculatorView(delegate: PlateCalculatorDelegate)
}

extension SetTrackerRowRouter {
    /// For a conformer that presents nothing (test doubles).
    func showPlateCalculatorView(delegate: PlateCalculatorDelegate) { }
}

extension CoreRouter: SetTrackerRowRouter { }
