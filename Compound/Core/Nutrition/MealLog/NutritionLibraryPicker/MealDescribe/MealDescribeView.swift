import SwiftUI

struct MealDescribeDelegate {
    let onPick: (MealItemModel) -> Void
    /// The plate's Log, handed on to the amount screen.
    var onLog: (() -> Void)?

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
                Text("Estimated by AI from your description, which is sent to Google's AI service for analysis and isn't stored by Compound. Try naming each food and its amount, such as \"2 eggs and a slice of toast.\"")
            }

            if let error = presenter.errorMessage {
                Section {
                    InlineMessage(.error, error)
                }
            } else if presenter.didAnalyse && presenter.analysisResults.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Foods Recognized", systemImage: Symbol.food)
                    } description: {
                        Text("Try naming each food and its amount, such as \"2 eggs and a slice of toast.\"")
                    }
                }
            } else if !presenter.analysisResults.isEmpty {
                Section {
                    ForEach(presenter.analysisResults) { item in
                        FoodAnalysisResultRow(item: item) {
                            presenter.onResultTapped(item, delegate: delegate)
                        }
                    }
                } header: {
                    AIEstimateHeader(count: presenter.analysisResults.count, isAdded: presenter.didAddAll) {
                        presenter.onAddAllPressed(delegate: delegate)
                    }
                } footer: {
                    Text("Estimates can be wrong. Check amounts before logging.")
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
                Text("Analyze")
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
