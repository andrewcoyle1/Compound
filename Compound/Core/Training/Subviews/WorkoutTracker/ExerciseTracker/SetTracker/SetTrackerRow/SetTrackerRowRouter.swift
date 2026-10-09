import SwiftUI

@MainActor
protocol SetTrackerRowRouter: GlobalRouter {
    func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void)
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

extension CoreRouter: SetTrackerRowRouter {
    /// A compact sheet with the contract's close and confirm, rather than the custom overlay it
    /// was. The sheet dismisses itself after either action, so callers only apply or discard.
    func showRestModal(
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonAction: @escaping () -> Void,
        minutesSelection: Binding<Int>,
        secondsSelection: Binding<Int>
    ) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            SetRestSheet(
                minutes: minutesSelection,
                seconds: secondsSelection,
                onClose: {
                    secondaryButtonAction()
                    router.dismissScreen()
                },
                onSave: {
                    primaryButtonAction()
                    router.dismissScreen()
                }
            )
        }
    }
}

/// The rest picker behind a set's Rest Timer swipe action and Exercise Settings' rest override.
struct SetRestSheet: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onClose: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60, id: \.self) { second in
                    Text("\(second) s").tag(second)
                }
            }
        }
        .pickerStyle(.wheel)
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Set Rest")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: onClose)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: onSave)
            }
        }
    }
}
