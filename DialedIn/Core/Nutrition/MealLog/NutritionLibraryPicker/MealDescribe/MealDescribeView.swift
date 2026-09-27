import SwiftUI

struct MealDescribeDelegate {
    let onPick: (MealItemModel) -> Void

    var eventParameters: [String: Any]? {
        nil
    }
}

struct MealDescribeView: View {

    @State var presenter: MealDescribePresenter
    let delegate: MealDescribeDelegate

    var body: some View {
        List {
            Section {
                PromptedTextEditor(
                    text: $presenter.descriptionText,
                    prompt: "Describe your meal"
                )
                .onChange(of: presenter.descriptionText) { _, newValue in
                    presenter.onDescriptionChanged(newValue)
                }
            } header: {
                HStack {
                    Text("Meal Description")
                    Spacer()
                    Text("\(presenter.descriptionText.count)/\(presenter.characterLimit)")
                        .monospacedDigit()
                }
            } footer: {
                Text("Common foods only")
            }

            if let error = presenter.errorMessage {
                Section {
                    InlineMessage(.error, error)
                }
            }

            if !presenter.analysisResults.isEmpty {
                Section("Results") {
                    ForEach(presenter.analysisResults) { item in
                        FoodAnalysisResultRow(item: item) {
                            presenter.onAddItem(item, delegate: delegate)
                        }
                    }
                }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isAnalysing) {
                Task { await presenter.onAnalysePressed() }
            } label: {
                Text("Analyse")
            }
            .disabled(!presenter.canAnalyse)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = MealDescribeDelegate(onPick: { _ in })

    return RouterView { router in
        builder.mealDescribeView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func mealDescribeView(router: AnyRouter, delegate: MealDescribeDelegate) -> some View {
        MealDescribeView(
            presenter: MealDescribePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showMealDescribeView(delegate: MealDescribeDelegate) {
        router.showScreen(.push) { router in
            builder.mealDescribeView(router: router, delegate: delegate)
        }
    }

}
