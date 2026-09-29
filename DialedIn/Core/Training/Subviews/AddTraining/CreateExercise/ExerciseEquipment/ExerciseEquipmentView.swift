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
                ActionRow(title: String(localized: "Bodyweight Exercise"), subtitle: String(localized: "This exercise is performed with bodyweight, without additional resistance.")) {
                    Toggle(isOn: $presenter.bodyweightExercise) { }
                        .accessibilityIdentifier("ExerciseEquipment.bodyweight")
                }
            }
            .listSectionMargins(.top, 0)

            if !presenter.bodyweightExercise {
                ForEach(Array(presenter.variations.enumerated()), id: \.element.id) { index, variation in
                    Section {
                        ActionRow(
                            title: String(localized: "Resistance"),
                            subtitle: presenter.resistanceSubtitle(for: variation),
                            subsubtitle: variation.resistanceEquipment.isEmpty ? "Required" : nil
                        ) {
                            Text("Add")
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color.secondary.opacity(0.5), in: .capsule)
                                .anyButton(.press) {
                                    presenter.onAddResistancePressed(variationId: variation.id)
                                }
                        }

                        ActionRow(
                            title: String(localized: "Support"),
                            subtitle: presenter.supportSubtitle(for: variation),
                            subsubtitle: variation.supportEquipment.isEmpty ? "Optional" : nil
                        ) {
                            Text("Add")
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color.secondary.opacity(0.5), in: .capsule)
                                .anyButton(.press) {
                                    presenter.onAddSupportPressed(variationId: variation.id)
                                }
                        }
                    } header: {
                        HStack {
                            Text(presenter.variationName(for: index))
                            Spacer()
                            if presenter.variations.count > 1 {
                                Button(role: .destructive) {
                                    presenter.onDeleteVariationPressed(id: variation.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .accessibilityLabel("Delete variation")
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        presenter.onAddVariationPressed()
                    } label: {
                        Label("Add Variation", systemImage: "plus.circle")
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
        .safeAreaInset(edge: .bottom) {
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
            .accessibilityIdentifier("ExerciseEquipment.next")
            .padding(.bottom)
            .opacity(presenter.canContinue ? 1 : 0.3)
            .disabled(!presenter.canContinue)
        }
    }
}

struct ActionRow<ActionArea: View>: View {

    var title: String
    var subtitle: String?
    var subsubtitle: String?
    var actionArea: () -> ActionArea

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let subsubtitle {
                        Text(subsubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    }
                }
            }
            Spacer()
            actionArea()
        }
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
