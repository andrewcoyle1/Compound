//
//  ExercisesPickerView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct ExercisesPickerDelegate {
    var addedExercises: Binding<[WorkoutTemplateExercise]>
}

struct ExercisesPickerView<ExerciseList: View>: View {

    @State var presenter: ExercisesPickerPresenter
    
    @ViewBuilder var exerciseListViewBuilder: (ExerciseListBuilderDelegate) -> ExerciseList
    
    var body: some View {
        
        let listDelegate = ExerciseListBuilderDelegate(
            onExerciseSelectionChanged: presenter.onExercisePressed,
            selectedExercises: presenter.selectedExercises
        )
        exerciseListViewBuilder(listDelegate)
            .navigationTitle(presenter.workingExercises.isEmpty ? String(localized: "Select at least one exercise") : String(AttributedString(localized: "^[\(presenter.workingExercises.count) exercise](inflect: true) selected").characters))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.onDismissPressed()
                    }
                    .accessibilityIdentifier("ExercisesPicker.close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        presenter.onSavePressed()
                    }
                    .accessibilityIdentifier("ExercisesPicker.confirm")
                    .disabled(!presenter.canSave)
                }

            }
            .interactiveDismissDisabled(presenter.hasUnsavedChanges)
            .onAppear { presenter.onViewAppear() }
            .onDisappear { presenter.onViewDisappear() }
    }
}

extension CoreBuilder {
    func exercisesPickerView(router: AnyRouter, delegate: ExercisesPickerDelegate) -> some View {
        ExercisesPickerView(
            presenter: ExercisesPickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            exerciseListViewBuilder: { delegate in
                exerciseListBuilderView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showExercisesPickerView(delegate: ExercisesPickerDelegate) {
        router.showScreen(.sheet) { router in
            builder.exercisesPickerView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    @Previewable @State var pickedExercises: [WorkoutTemplateExercise] = []
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ExercisesPickerDelegate(addedExercises: $pickedExercises)
    
    RouterView { router in
        builder.exercisesPickerView(router: router, delegate: delegate)
    }
    
}
