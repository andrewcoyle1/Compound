//
//  SwapExercisePickerView.swift
//  Compound
//

import SwiftUI

struct SwapExercisePickerView: View {

    @State var presenter: SwapExercisePickerPresenter

    var body: some View {
        List(presenter.filteredExercises) { exercise in
            Button {
                presenter.onExerciseSelected(exercise)
            } label: {
                ListRow(title: exercise.name, imageName: exercise.imageURL, resizingMode: .fit, initialsWhenMissing: true)
                    .contentShape(.rect)
            }
        }
        .searchable(text: $presenter.searchText, prompt: String(localized: "Search exercises"))
        .navigationTitle("Swap Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }
}

extension CoreBuilder {
    func swapExercisePickerView(router: AnyRouter, onSelect: @escaping (ExerciseModel) -> Void) -> some View {
        SwapExercisePickerView(
            presenter: SwapExercisePickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                onSelect: onSelect
            )
        )
    }
}

extension CoreRouter {
    /// The choice is handed over once the sheet is down, so a question it raises (swapping away
    /// logged sets) is asked from the tracker rather than lost under a closing sheet.
    func showSwapExercisePickerView(onSelect: @escaping (ExerciseModel) -> Void) {
        var selected: ExerciseModel?
        router.showScreen(
            .sheet,
            onDidDismiss: {
                if let selected { onSelect(selected) }
            },
            destination: { router in
                builder.swapExercisePickerView(router: router, onSelect: { selected = $0 })
            }
        )
    }
}
