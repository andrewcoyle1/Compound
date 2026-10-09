import SwiftUI

/// What the add form needs from the machine. The stacks it already has are only read, for the
/// duplicate checks, so they are passed as a value; the new stack goes back through `onAdd`.
struct AddWeightStackDelegate {
    var machineName: String
    var stacks: [WeightStack]
    var unit: ExerciseWeightUnit
    var onAdd: (WeightStack) -> Void
}

struct AddWeightStackView: View {

    @State var presenter: AddWeightStackPresenter

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Label"), text: $presenter.range.name)
                    .font(.rowTitle)
                WeightStackGridFields(stack: $presenter.range)
            }
            if let message = presenter.validationMessage {
                Section {
                    InlineMessage(.info, message)
                }
            }
        }
        .navigationTitle("Add Range")
        .navigationSubtitle(presenter.delegate.machineName)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed()
            }
            .disabled(presenter.validationMessage != nil)
        }
    }
}

/// The lightest pin, the heaviest and the step between: the three numbers of an even stack, shared
/// by the add and edit forms.
struct WeightStackGridFields: View {
    @Binding var stack: WeightStack

    var body: some View {
        let unit = stack.unit.abbreviation
        NumberField("0", value: number(\.minWeight), unit: unit, label: String(localized: "Lightest pin"))
        NumberField("0", value: number(\.maxWeight), unit: unit, label: String(localized: "Heaviest pin"))
        NumberField("0", value: number(\.increment), unit: unit, label: String(localized: "Increment"))
    }

    /// A cleared field reads as 0; the edit form repairs an unusable stack as it closes, and the
    /// add form will not save one.
    private func number(_ keyPath: WritableKeyPath<WeightStack, Double>) -> Binding<Double?> {
        Binding(get: { stack[keyPath: keyPath] }, set: { stack[keyPath: keyPath] = $0 ?? 0 })
    }
}

extension CoreBuilder {

    func addWeightStackView(router: AnyRouter, delegate: AddWeightStackDelegate) -> some View {
        AddWeightStackView(
            presenter: AddWeightStackPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {

    func showAddWeightStackView(delegate: AddWeightStackDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.addWeightStackView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddWeightStackDelegate(machineName: CableMachine.mock.name, stacks: CableMachine.mock.ranges, unit: .kilograms) { _ in }
    return RouterView { router in
        builder.addWeightStackView(router: router, delegate: delegate)
    }
}
