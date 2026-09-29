//
//  WorkoutExerciseEquipmentSheetView.swift
//  DialedIn
//
//  Sheet that displays equipment variations for an exercise and lets the user pick one.
//

import SwiftUI

struct WorkoutExerciseEquipmentSheetDelegate {
    let exercise: Binding<WorkoutExerciseModel>
    let onSelect: (String?) -> Void
}

struct WorkoutExerciseEquipmentSheetView: View {

    @State var presenter: WorkoutExerciseEquipmentSheetPresenter
    let delegate: WorkoutExerciseEquipmentSheetDelegate

    var body: some View {
        Group {
            if presenter.isLoading {
                ProgressView("Loading variations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = presenter.loadError {
                ContentUnavailableView {
                    Label("No Equipment", systemImage: Symbol.equipment)
                } description: {
                    Text(error)
                }
            } else {
                List {
                    Section {
                        ForEach(presenter.variationItems) { item in
                            variationRow(item: item)
                        }
                    }
                    .listSectionMargins(.top, 0)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(delegate.exercise.wrappedValue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onCancelPressed()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    presenter.onDonePressed(onSelect: delegate.onSelect)
                }
            }
        }
        .task {
            await presenter.loadVariations(exercise: delegate.exercise.wrappedValue)
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func variationRow(item: VariationDisplayItem) -> some View {
        SelectableRow(
            title: item.name,
            subtitle: presenter.detail(for: item),
            isSelected: presenter.chosenVariationId == item.id
        ) {
            presenter.onSelectVariation(id: item.id)
        }
    }
}

#Preview {
    @Previewable @State var exercise: WorkoutExerciseModel = .mock
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    let delegate = WorkoutExerciseEquipmentSheetDelegate(exercise: $exercise) { _ in }
    RouterView { router in
        builder.workoutExerciseEquipmentSheetView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    func workoutExerciseEquipmentSheetView(router: AnyRouter, delegate: WorkoutExerciseEquipmentSheetDelegate) -> some View {
        WorkoutExerciseEquipmentSheetView(
            presenter: WorkoutExerciseEquipmentSheetPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWorkoutExerciseEquipmentSheetView(delegate: WorkoutExerciseEquipmentSheetDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.workoutExerciseEquipmentSheetView(router: router, delegate: delegate)
        }
    }
}
