import SwiftUI

struct RestTimerSettingsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct RestTimerSettingsView: View {

    @State var presenter: RestTimerSettingsPresenter
    let delegate: RestTimerSettingsDelegate

    var body: some View {
        List {
            behaviourSection
            notificationsSection
            scalingSection
        }
        .navigationTitle("Rest Timer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isEditingScaling) {
            if let type = presenter.editingScaling {
                scalingPicker(for: type)
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Sections

    private var behaviourSection: some View {
        Section {
            CustomLabelButtonView(
                symbolName: "heart.fill",
                title: String(localized: "Timer Duration"),
                subtitle: String(localized: "Configure rest duration for different exercise types")) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .padding()
                        .anyButton(.press) {
                            presenter.onTimerDurationPressed()
                        }
                    .accessibilityLabel("Timer Duration")
                }
            CustomToggleView(
                symbolName: "flag",
                title: String(localized: "Rest After Last Warm-Up Set"),
                subtitle: String(localized: "Rest before the first working set. Warm-up sets never rest between themselves"),
                bool: $presenter.restAfterLastWarmUp
            )
            CustomToggleView(
                symbolName: "checkmark.circle.fill",
                title: String(localized: "Rest Between Exercises"),
                subtitle: String(localized: "Use rest timers when moving between exercises"),
                bool: $presenter.restBetweenExercises
            )
            CustomToggleView(
                symbolName: "signpost.right.and.left.fill",
                title: String(localized: "Rest Between Left/Right Sets"),
                subtitle: String(localized: "Use rest timers in between left and right sets"),
                bool: $presenter.restBetweenSideSets
            )
        } header: {
            Text("Behaviour")
        }
    }

    private var notificationsSection: some View {
        Section {
            CustomToggleView(
                symbolName: "timer",
                title: String(localized: "Use Rest Timers"),
                subtitle: String(localized: "Rest timers will count down after each exercise set"),
                bool: $presenter.useRestTimers
            )
            CustomToggleView(
                symbolName: "music.note",
                title: String(localized: "Play Sound"),
                subtitle: String(localized: "Play sound when rest time is over"),
                bool: $presenter.restTimerPlaySound
            )
            CustomToggleView(
                symbolName: "apple.haptics.and.exclamationmark.triangle",
                title: String(localized: "Vibrate"),
                subtitle: String(localized: "Vibrate when rest time is over"),
                bool: $presenter.restTimerVibrate
            )
        } header: {
            Text("Notifications")
        }
    }

    private var scalingSection: some View {
        Section {
            CustomLabelButtonView(
                symbolName: "figure.yoga",
                title: String(localized: "Rest After Last Warm-Up Set"),
                subtitle: presenter.formattedScaling(presenter.warmUpRestScaling)) {
                    Text("Edit")
                        .padding(.horizontal, 8)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2), in: .capsule)
                        .anyButton(.press) {
                            presenter.onEditWarmUpScalingPressed()
                        }
                }
            CustomLabelButtonView(
                symbolName: "checkmark.circle.fill",
                title: String(localized: "Rest Between Exercises"),
                subtitle: presenter.formattedScaling(presenter.betweenExercisesRestScaling)) {
                    Text("Edit")
                        .padding(.horizontal, 8)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2), in: .capsule)
                        .anyButton(.press) {
                            presenter.onEditBetweenExercisesScalingPressed()
                        }
                }
            CustomLabelButtonView(
                symbolName: "signpost.right.and.left.fill",
                title: String(localized: "Rest Between Left/Right Sets"),
                subtitle: presenter.formattedScaling(presenter.sideSetRestScaling)) {
                    Text("Edit")
                        .padding(.horizontal, 8)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2), in: .capsule)
                        .anyButton(.press) {
                            presenter.onEditSideSetsScalingPressed()
                        }
                }
        } header: {
            Text("Rest Scaling")
        }
    }

    // MARK: - Scaling Picker Sheet

    @ViewBuilder
    private func scalingPicker(for type: RestTimerSettingsPresenter.ScalingType) -> some View {
        let options: [(label: String, value: Double)] = [
            ("25%", 0.25), ("50%", 0.50), ("75%", 0.75),
            ("100%", 1.0), ("125%", 1.25), ("150%", 1.50), ("200%", 2.0)
        ]
        let current = presenter.currentScaling(for: type)
        NavigationStack {
            List {
                ForEach(options, id: \.value) { option in
                    HStack {
                        Text(option.label)
                        Spacer()
                        if abs(current - option.value) < 0.001 {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .anyButton(.press) {
                        presenter.updateScaling(for: type, value: option.value)
                    }
                }
            }
            .navigationTitle(type.label)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = RestTimerSettingsDelegate()

    return RouterView { router in
        builder.restTimerSettingsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func restTimerSettingsView(router: AnyRouter, delegate: RestTimerSettingsDelegate) -> some View {
        RestTimerSettingsView(
            presenter: RestTimerSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.restTimerSettingsView(router: router, delegate: delegate)
        }
    }

}
