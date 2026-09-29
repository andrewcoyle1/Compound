import SwiftUI

struct MuscleGroupPickerDelegate {
    let name: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    let exerciseType: ExerciseType?
    let laterality: Laterality?
}

struct MuscleGroupPickerView: View {
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
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
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(presenter.primaryCount) primary, \(presenter.secondaryCount) secondary")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !presenter.selectedMuscleGroups.isEmpty {
                        Text("Reset")
                            .underline()
                            .anyButton(.press) {
                                presenter.onResetPressed()
                            }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                CallToActionButton(isPrimaryAction: !presenter.selectedMuscleGroups.isEmpty ? true : false) {
                    presenter.onNextPressed(delegate: delegate)
                } label: {
                    Text(!presenter.selectedMuscleGroups.isEmpty ? String(localized: "Next") : String(localized: "Skip"))
                }
                .accessibilityIdentifier("MuscleGroupPicker.next")
            }
            .padding(.bottom)
            .background(.bar)
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
    
    @ViewBuilder
    private func muscleView(_ muscle: Muscles) -> some View {
        VStack(alignment: .center) {
            ZStack(alignment: .bottomTrailing) {
                ImageLoaderView()
                    .aspectRatio(contentMode: .fill)
                if let selected = presenter.selectedMuscleGroups[muscle] {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.primary, lineWidth: 12)
                
                ZStack {
                    Circle()
                        .foregroundStyle(colorScheme.backgroundPrimary)
                    Text(selected == .primary ? String(localized: "P") : String(localized: "S"))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .frame(width: 16, height: 16)
                .padding(8)
                }
            }
            .cornerRadius(16)

            Text(muscle.name)
                .font(.subheadline)
                .lineLimit(1)
        }
        .anyButton(.press) {
            presenter.onMuscleGroupPressed(muscle: muscle)
        }
        .accessibilityIdentifier("MuscleGroupPicker.\(muscle.name)")
        .padding(8)
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
