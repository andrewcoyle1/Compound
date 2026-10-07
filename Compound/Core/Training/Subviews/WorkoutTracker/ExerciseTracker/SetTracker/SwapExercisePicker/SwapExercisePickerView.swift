//
//  SwapExercisePickerView.swift
//  Compound
//

import SwiftUI

struct SwapExercisePickerView: View {

    @State var presenter: SwapExercisePickerPresenter

    var body: some View {
        List {
            let alternatives = presenter.plannedAlternatives
            if !alternatives.isEmpty {
                Section("Planned alternatives") {
                    ForEach(alternatives) { exercise in
                        row(exercise)
                    }
                }
            }
            Section {
                ForEach(presenter.filteredExercises) { exercise in
                    row(exercise)
                }
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
        .onAppear {
            presenter.onViewAppear()
        }
    }

    private func row(_ exercise: ExerciseModel) -> some View {
        Button {
            presenter.onExerciseSelected(exercise)
        } label: {
            ListRow(title: exercise.name, imageName: exercise.imageURL, resizingMode: .fit, initialsWhenMissing: true)
                .contentShape(.rect)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.swapExercisePickerView(
            router: router,
            alternativeIds: ExerciseModel.mocks.prefix(2).map(\.id),
            onSelect: { _ in }
        )
    }
}

extension CoreBuilder {
    func swapExercisePickerView(
        router: AnyRouter,
        alternativeIds: [String] = [],
        onSelect: @escaping (ExerciseModel) -> Void
    ) -> some View {
        SwapExercisePickerView(
            presenter: SwapExercisePickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                alternativeIds: alternativeIds,
                onSelect: onSelect
            )
        )
    }
}

extension CoreRouter {
    /// The choice is handed over once the sheet is down, so a question it raises (swapping away
    /// logged sets) is asked from the tracker rather than lost under a closing sheet.
    func showSwapExercisePickerView(alternativeIds: [String], onSelect: @escaping (ExerciseModel) -> Void) {
        var selected: ExerciseModel?
        router.showScreen(
            .sheet,
            onDidDismiss: {
                if let selected { onSelect(selected) }
            },
            destination: { router in
                builder.swapExercisePickerView(router: router, alternativeIds: alternativeIds, onSelect: { selected = $0 })
            }
        )
    }
}
