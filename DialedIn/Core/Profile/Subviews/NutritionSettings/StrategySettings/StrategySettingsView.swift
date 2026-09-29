import SwiftUI

struct StrategySettingsDelegate {
    
}

struct StrategySettingsView: View {
    
    @State var presenter: StrategySettingsPresenter
    let delegate: StrategySettingsDelegate
    
    var body: some View {
        List {
            Section {
                CustomLabelButtonView(
                    symbolName: "calendar",
                    title: String(localized: "Check-in Day"),
                    subtitle: presenter.checkInWeekdayName) {
                        Text("Edit")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.onEditCheckInDayPressed()
                            }
                    }
                CustomToggleView(
                    symbolName: "hare",
                    title: String(localized: "Fast Check-in"),
                    subtitle: presenter.fastCheckInEnabled ? String(localized: "On") : String(localized: "Off"),
                    bool: Binding(
                        get: { presenter.fastCheckInEnabled },
                        set: { presenter.fastCheckInEnabled = $0 }
                    )
                )
            } header: {
                Text("General")
            }

            Section {
                Label("Introduction", systemImage: "info")
                CustomToggleView(
                    title: String(localized: "Partial Logging"),
                    subtitle: nil,
                    bool: Binding(
                        get: { presenter.partialLoggingEnabled },
                        set: { presenter.partialLoggingEnabled = $0 }
                    )
                )
                CustomToggleView(
                    title: String(localized: "Weigh-In"),
                    subtitle: nil,
                    bool: Binding(
                        get: { presenter.weighInEnabled },
                        set: { presenter.weighInEnabled = $0 }
                    )
                )
                CustomToggleView(
                    title: String(localized: "Fasting"),
                    subtitle: nil,
                    bool: Binding(
                        get: { presenter.fastingEnabled },
                        set: { presenter.fastingEnabled = $0 }
                    )
                )
                CustomToggleView(
                    title: String(localized: "Logging Break"),
                    subtitle: nil,
                    bool: Binding(
                        get: { presenter.loggingBreakEnabled },
                        set: { presenter.loggingBreakEnabled = $0 }
                    )
                )
                Label("Program Update", systemImage: "star.fill")
            } header: {
                Text("Coaching Modules")
            } footer: {
                Text("Individually configure which modules can appear during your check in.")
            }
        }
        .navigationTitle("Strategy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isChoosingCheckInDay) {
            checkInDayPicker
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private var checkInDayPicker: some View {
        NavigationStack {
            List {
                ForEach(presenter.weekdayOptions, id: \.weekday) { option in
                    HStack {
                        Text(option.name)
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .opacity(presenter.checkInWeekday == option.weekday ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.checkInWeekday = option.weekday
                        presenter.isChoosingCheckInDay = false
                    }
                }
            }
            .navigationTitle("Check-in Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presenter.isChoosingCheckInDay = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension CoreBuilder {
    
    func strategySettingsView(router: AnyRouter, delegate: StrategySettingsDelegate) -> some View {
        StrategySettingsView(
            presenter: StrategySettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showStrategySettingsView(delegate: StrategySettingsDelegate) {
        router.showScreen(.push) { router in
            builder.strategySettingsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = StrategySettingsDelegate()
    
    return RouterView { router in
        builder.strategySettingsView(router: router, delegate: delegate)
    }
    
}
