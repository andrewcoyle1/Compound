import SwiftUI

struct MuscleGroupPickerDelegate {
    let name: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    let exerciseType: ExerciseType?
    let laterality: Laterality?
}

struct MuscleGroupPickerView: View {
    
    @State var presenter: MuscleGroupPickerPresenter
    let delegate: MuscleGroupPickerDelegate
    
    var body: some View {
        List {
            upperSection
            lowerSection
        }
        .navigationTitle("Select Muscles")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationSubtitle(String(localized: "\(presenter.primaryCount) primary, \(presenter.secondaryCount) secondary"))
        .toolbar {
            if !presenter.selectedMuscleGroups.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        presenter.onResetPressed()
                    }
                }
            }
        }
        .bottomCTA {
            CallToActionButton(isPrimaryAction: !presenter.selectedMuscleGroups.isEmpty) {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text(!presenter.selectedMuscleGroups.isEmpty ? String(localized: "Next") : String(localized: "Skip"))
            }
            .accessibilityIdentifier("MuscleGroupPicker.next")
        }
    }

    private var upperSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                ForEach(presenter.upperMuscles, id: \.self) { muscle in
                    muscleView(muscle)
                }
            }
            .removeListRowFormatting()
        } header: {
            Text("Upper")
        }
        .listSectionMargins(.vertical, 0)
    }
    
    private var lowerSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                ForEach(presenter.lowerMuscles, id: \.self) { muscle in
                    muscleView(muscle)
                }
            }
            .removeListRowFormatting()
        } header: {
            Text("Lower")
        }
        .listSectionMargins(.top, 0)

    }
    
    private func muscleView(_ muscle: Muscles) -> some View {
        let selected = presenter.selectedMuscleGroups[muscle]
        return VStack(alignment: .center) {
            ZStack(alignment: .bottomTrailing) {
                ImageLoaderView()
                    .aspectRatio(contentMode: .fill)
                if let selected {
                    RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                        .stroke(.tint, lineWidth: 12)

                    // The letter says which, so primary and secondary never differ by colour alone.
                    Text(selected == .primary ? String(localized: "P") : String(localized: "S"))
                        .font(.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.onAccent)
                        .padding(Spacing.xs)
                        .background(.tint, in: .circle)
                        .padding(Spacing.s)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.l, style: .continuous))

            Text(muscle.name)
                .font(.rowDetail)
                .lineLimit(1)
        }
        .anyButton(.press) {
            presenter.onMuscleGroupPressed(muscle: muscle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(muscle.name)
        .accessibilityValue(selectionDescription(selected))
        .accessibilityAddTraits(selected != nil ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("MuscleGroupPicker.\(muscle.name)")
        .padding(Spacing.s)
    }

    private func selectionDescription(_ selected: MuscleTargetType?) -> String {
        switch selected {
        case .primary: String(localized: "Primary")
        case .secondary: String(localized: "Secondary")
        case nil: String(localized: "Not selected")
        }
    }
}

extension CoreBuilder {
    
    func muscleGroupPickerView(router: AnyRouter, delegate: MuscleGroupPickerDelegate) -> some View {
        MuscleGroupPickerView(
            presenter: MuscleGroupPickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showMuscleGroupPickerView(delegate: MuscleGroupPickerDelegate) {
        router.showScreen(.push) { router in
            builder.muscleGroupPickerView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = MuscleGroupPickerDelegate(
        name: "Bench Press",
        trackableMetricA: .reps,
        trackableMetricB: .weight,
        exerciseType: .compoundUpper,
        laterality: .bilateral
    )
    
    return RouterView { router in
        builder.muscleGroupPickerView(router: router, delegate: delegate)
    }
    
}
