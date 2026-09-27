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
            ListRowButton(
                title: String(localized: "Timer Duration"),
                subtitle: String(localized: "Configure rest duration for different exercise types"),
                systemImage: Symbol.duration
            ) {
                presenter.onTimerDurationPressed()
            }
            ListRowToggle(
                title: String(localized: "Rest After Last Warm-Up Set"),
                subtitle: String(localized: "Rest before the first working set. Warm-up sets never rest between themselves"),
                systemImage: "flag",
                isOn: $presenter.restAfterLastWarmUp
            )
            ListRowToggle(
                title: String(localized: "Rest Between Exercises"),
                subtitle: String(localized: "Use rest timers when moving between exercises"),
                systemImage: "arrow.forward.circle",
                isOn: $presenter.restBetweenExercises
            )
            ListRowToggle(
                title: String(localized: "Rest Between Left/Right Sets"),
                subtitle: String(localized: "Use rest timers in between left and right sets"),
                systemImage: "signpost.right.and.left.fill",
                isOn: $presenter.restBetweenSideSets
            )
        } header: {
            Text("Behaviour")
        }
    }

    private var notificationsSection: some View {
        Section {
            ListRowToggle(
                title: String(localized: "Use Rest Timers"),
                subtitle: String(localized: "Rest timers will count down after each exercise set"),
                systemImage: Symbol.rest,
                isOn: $presenter.useRestTimers
            )
            ListRowToggle(
                title: String(localized: "Play Sound"),
                subtitle: String(localized: "Play sound when rest time is over"),
                systemImage: "music.note",
                isOn: $presenter.restTimerPlaySound
            )
            ListRowToggle(
                title: String(localized: "Vibrate"),
                subtitle: String(localized: "Vibrate when rest time is over"),
                systemImage: "apple.haptics.and.exclamationmark.triangle",
                isOn: $presenter.restTimerVibrate
            )
        } header: {
            Text("Notifications")
        }
    }

    private var scalingSection: some View {
        Section {
            ListRowButton(
                title: String(localized: "Rest After Last Warm-Up Set"),
                subtitle: presenter.formattedScaling(presenter.warmUpRestScaling),
                systemImage: "figure.yoga"
            ) {
                presenter.onEditWarmUpScalingPressed()
            }
            ListRowButton(
                title: String(localized: "Rest Between Exercises"),
                subtitle: presenter.formattedScaling(presenter.betweenExercisesRestScaling),
                systemImage: "arrow.forward.circle"
            ) {
                presenter.onEditBetweenExercisesScalingPressed()
            }
            ListRowButton(
                title: String(localized: "Rest Between Left/Right Sets"),
                subtitle: presenter.formattedScaling(presenter.sideSetRestScaling),
                systemImage: "signpost.right.and.left.fill"
            ) {
                presenter.onEditSideSetsScalingPressed()
            }
        } header: {
            Text("Rest Scaling")
        }
    }

    // MARK: - Scaling Picker Sheet

    @ViewBuilder
    private func scalingPicker(for type: RestTimerSettingsPresenter.ScalingType) -> some View {
        let options: [Double] = [0.25, 0.50, 0.75, 1.0, 1.25, 1.50, 2.0]
        let current = presenter.currentScaling(for: type)
        NavigationStack {
            List {
                ForEach(options, id: \.self) { option in
                    SelectableRow(title: presenter.formattedScaling(option), isSelected: abs(current - option) < 0.001) {
                        presenter.updateScaling(for: type, value: option)
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
