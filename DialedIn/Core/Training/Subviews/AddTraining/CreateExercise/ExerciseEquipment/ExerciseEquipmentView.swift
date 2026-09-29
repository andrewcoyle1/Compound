import SwiftUI

struct ExerciseEquipmentDelegate {
    let name: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    let exerciseType: ExerciseType?
    let laterality: Laterality?
    let muscleGroups: [Muscles: MuscleTargetType]
}

struct ExerciseEquipmentView: View {

    @State var presenter: ExerciseEquipmentPresenter
    let delegate: ExerciseEquipmentDelegate

    var body: some View {
        List {
            Section {
                ListRowToggle(
                    title: String(localized: "Bodyweight Exercise"),
                    subtitle: String(localized: "This exercise is performed with bodyweight, without additional resistance."),
                    isOn: $presenter.bodyweightExercise
                )
                .accessibilityIdentifier("ExerciseEquipment.bodyweight")
            }
            .listSectionMargins(.top, 0)

            if !presenter.bodyweightExercise {
                ForEach(Array(presenter.variations.enumerated()), id: \.element.id) { index, variation in
                    Section {
                        addRow(
                            title: String(localized: "Resistance"),
                            subtitle: presenter.resistanceSubtitle(for: variation),
                            note: variation.resistanceEquipment.isEmpty ? String(localized: "Required") : nil
                        ) {
                            presenter.onAddResistancePressed(variationId: variation.id)
                        }

                        addRow(
                            title: String(localized: "Support"),
                            subtitle: presenter.supportSubtitle(for: variation),
                            note: variation.supportEquipment.isEmpty ? String(localized: "Optional") : nil
                        ) {
                            presenter.onAddSupportPressed(variationId: variation.id)
                        }
                    } header: {
                        HStack {
                            Text(presenter.variationName(for: index))
                            Spacer()
                            if presenter.variations.count > 1 {
                                Button(role: .destructive) {
                                    presenter.onDeleteVariationPressed(id: variation.id)
                                } label: {
                                    Image(systemName: Symbol.delete)
                                }
                                .accessibilityLabel("Delete variation")
                                .buttonStyle(.plain)
                                .foregroundStyle(.danger)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        presenter.onAddVariationPressed()
                    } label: {
                        Label("Add Variation", systemImage: Symbol.add)
                    }
                }
            }
        }
        .navigationTitle("Select Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
            .accessibilityIdentifier("ExerciseEquipment.next")
            .disabled(!presenter.canContinue)
        }
    }

    /// `note` says whether the equipment is required, and joins the subtitle rather than taking a
    /// third line.
    private func addRow(title: String, subtitle: String?, note: String?, action: @escaping () -> Void) -> some View {
        let detail = [subtitle, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return ListRow(
            title: title,
            subtitle: detail.isEmpty ? nil : detail,
            accessory: .custom(AnyView(RowChipButton("Add", subject: title, action: action)))
        )
    }
}

extension CoreBuilder {

    func exerciseEquipmentView(router: AnyRouter, delegate: ExerciseEquipmentDelegate) -> some View {
        ExerciseEquipmentView(
            presenter: ExerciseEquipmentPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showExerciseEquipmentView(delegate: ExerciseEquipmentDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseEquipmentView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ExerciseEquipmentDelegate(
        name: "Bench Press",
        trackableMetricA: .reps,
        trackableMetricB: .weight,
        exerciseType: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: [:]
    )

    return RouterView { router in
        builder.exerciseEquipmentView(router: router, delegate: delegate)
    }

}
