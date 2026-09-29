import SwiftUI

struct MuscleGroupPickerDelegate {
    let name: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    let exerciseType: ExerciseType?
    let laterality: Laterality?
}

struct MuscleGroupPickerView: View {
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State var presenter: MuscleGroupPickerPresenter
    let delegate: MuscleGroupPickerDelegate
    
    var body: some View {
        List {
            instructionSection
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

    private var instructionSection: some View {
        Section {
            Text("Tap a muscle once for Primary, again for Secondary, and a third time to clear it.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    /// Fewer, wider tiles at accessibility text sizes, so muscle names wrap instead of truncating.
    private var columns: [GridItem] {
        let count = dynamicTypeSize >= .accessibility3 ? 1 : (dynamicTypeSize.isAccessibilitySize ? 2 : 3)
        return Array(repeating: GridItem(), count: count)
    }

    private var upperSection: some View {
        Section {
            LazyVGrid(columns: columns) {
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
            LazyVGrid(columns: columns) {
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
            ZStack(alignment: .bottom) {
                // swiftlint:disable:next todo
                // TODO: Every tile shows the same placeholder image. Replace it with each muscle's own artwork once that exists (artwork is planned).
                ImageLoaderView()
                    .aspectRatio(contentMode: .fill)
                if let selected {
                    // A thicker ring for Primary, and the badge names which, so the two never
                    // differ by colour alone.
                    RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                        .stroke(.tint, lineWidth: selected == .primary ? 12 : 6)

                    Text(selectionDescription(selected))
                        .font(.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xxs)
                        .background(.tint, in: .capsule)
                        .padding(Spacing.s)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.l, style: .continuous))

            Text(muscle.name)
                .font(.rowDetail)
                .multilineTextAlignment(.center)
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
