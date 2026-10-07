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
            if presenter.plansSets {
                withinASetSection
                amrapSection
            }
        }
        .navigationTitle("Rest Timer")
        .navigationBarTitleDisplayMode(.inline)
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
            // The master switch, first rather than under Notifications.
            ListRowToggle(
                title: String(localized: "Use Rest Timers"),
                subtitle: String(localized: "Rest timers will count down after each exercise set"),
                systemImage: Symbol.rest,
                isOn: $presenter.useRestTimers
            )
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
            Text("Behavior")
        }
    }

    private var notificationsSection: some View {
        Section {
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
            ForEach(RestTimerSettingsPresenter.ScalingType.allCases) { type in
                Picker(type.label, selection: Binding(
                    get: { presenter.currentScaling(for: type) },
                    set: { presenter.updateScaling(for: type, value: $0) }
                )) {
                    ForEach(RestTimerSettingsPresenter.scalingOptions, id: \.self) { option in
                        Text(presenter.formattedScaling(option)).tag(option)
                    }
                }
            }
        } header: {
            Text("Rest Scaling")
        }
    }

    // MARK: - Set Plan

    private var withinASetSection: some View {
        Section {
            ListRow(
                title: String(localized: "Drop set"),
                subtitle: String(localized: "Change the weight and go"),
                accessory: .value(String(localized: "None"))
            )
            ForEach(RestTimerSettingsPresenter.IntraSetKind.allCases) { kind in
                ListRow(
                    title: kind.title,
                    subtitle: kind.subtitle,
                    accessory: .custom(AnyView(intraSetRestChips(for: kind)))
                )
            }
        } header: {
            Text("Within a Set")
        } footer: {
            Text("A set's normal rest follows its last piece. The Live Activity shows the short rest as a bar, not a countdown, and buzzes once.")
        }
    }

    private func intraSetRestChips(for kind: RestTimerSettingsPresenter.IntraSetKind) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(kind.options, id: \.self) { seconds in
                Button {
                    presenter.onIntraSetRestSelected(seconds, for: kind)
                } label: {
                    Chip(presenter.secondsTitle(seconds), isSelected: presenter.intraSetRest(for: kind) == seconds)
                        .chipTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(presenter.intraSetRestAccessibilityLabel(seconds, for: kind))
            }
        }
    }

    private var amrapSection: some View {
        Section {
            ListRowToggle(
                title: String(localized: "Raise the Target"),
                subtitle: String(localized: "After beating it twice in a row"),
                systemImage: "arrow.up.right",
                isOn: $presenter.amrapRaisesTarget
            )
            Group {
                ListRowToggle(
                    title: String(localized: "Add Weight Instead"),
                    subtitle: presenter.amrapAddsWeightSubtitle,
                    systemImage: Symbol.add,
                    isOn: $presenter.amrapAddsWeight
                )
                if presenter.amrapAddsWeight {
                    Stepper(value: $presenter.amrapWeightCeiling, in: presenter.amrapCeilingRange) {
                        Text("Target \(presenter.amrapWeightCeiling)")
                    }
                    .accessibilityLabel("Target that adds weight")
                    .accessibilityValue("\(presenter.amrapWeightCeiling)")
                }
            }
            // Without raising the target there is no ceiling to reach.
            .disabled(!presenter.amrapRaisesTarget)
        } header: {
            Text("AMRAP")
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
