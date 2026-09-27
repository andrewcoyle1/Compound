//
//  SwapExercisePickerView.swift
//  DialedIn
//

import SwiftUI

struct SwapExercisePickerView: View {

    @State var presenter: SwapExercisePickerPresenter

    var body: some View {
        List(presenter.filteredExercises) { exercise in
            Button {
                presenter.onExerciseSelected(exercise)
            } label: {
                ListRow(title: exercise.name, imageName: exercise.imageURL ?? Constants.randomImage, resizingMode: .fit)
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
    func showSwapExercisePickerView(onSelect: @escaping (ExerciseModel) -> Void) {
        router.showScreen(.sheet) { router in
            builder.swapExercisePickerView(router: router, onSelect: onSelect)
        }
    }
}
