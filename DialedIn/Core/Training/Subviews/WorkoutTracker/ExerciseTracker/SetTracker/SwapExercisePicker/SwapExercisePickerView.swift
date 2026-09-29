//
//  SwapExercisePickerView.swift
//  DialedIn
//

import SwiftUI

struct SwapExercisePickerView: View {

    @State var presenter: SwapExercisePickerPresenter

    var body: some View {
        NavigationStack {
            List(presenter.filteredExercises) { exercise in
                Button {
                    presenter.onExerciseSelected(exercise)
                } label: {
                    HStack {
                        ImageLoaderView(urlString: exercise.imageURL ?? Constants.randomImage, resizingMode: .fit)
                            .frame(width: 36, height: 36)
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $presenter.searchText, prompt: String(localized: "Search exercises"))
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        presenter.onDismissPressed()
                    }
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
