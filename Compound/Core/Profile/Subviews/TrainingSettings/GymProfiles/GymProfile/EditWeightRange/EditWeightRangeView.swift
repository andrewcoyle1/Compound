import SwiftUI

struct EditWeightRangeDelegate {
    var equipmentName: String
    var range: Binding<WeightStack>
}

/// One stack of a cable or pin-loaded machine: its pins (an even grid, or an uneven list) and the
/// add-on weights on top.
struct EditWeightRangeView: View {

    @State var presenter: EditWeightRangePresenter

    var body: some View {
        Form {
            if !presenter.isUneven {
                Section {
                    WeightStackGridFields(stack: $presenter.stack)
                }
            }
            unevenSection
            addOnsSection
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Edit Range")
        .navigationSubtitle(presenter.equipmentName)
        .navigationBarTitleDisplayMode(.inline)
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

    private var unit: String { presenter.stack.unit.abbreviation }

    private var unevenSection: some View {
        Section {
            Toggle("Uneven stack", isOn: $presenter.isUneven)
            if let weights = presenter.stack.weights {
                ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                    Text(GymEquipmentFormat.weight(weight, presenter.stack.unit))
                        .font(.rowTitle)
                }
                .onDelete { presenter.onDeletePinWeights(at: $0) }
                HStack(spacing: Spacing.s) {
                    NumberField(String(localized: "Pin weight"), value: $presenter.newPinWeight, unit: unit)
                    Button("Add") { presenter.onAddPinWeightPressed() }
                        .buttonStyle(.borderless)
                        .disabled(!presenter.canAddPinWeight)
                }
                if let message = presenter.pinWeightMessage {
                    InlineMessage(.info, message)
                }
            }
        } footer: {
            Text("For a stack whose plates are not all the same weight: list every weight the pin can select.")
        }
    }

    private var addOnsSection: some View {
        Section {
            ForEach(Array(presenter.stack.addOns.enumerated()), id: \.offset) { _, addOn in
                Text("+" + GymEquipmentFormat.weight(addOn, presenter.stack.unit))
                    .font(.rowTitle)
            }
            .onDelete { presenter.onDeleteAddOns(at: $0) }
            HStack(spacing: Spacing.s) {
                NumberField(String(localized: "Add-on weight"), value: $presenter.newAddOn, unit: unit)
                Button("Add") { presenter.onAddAddOnPressed() }
                    .buttonStyle(.borderless)
                    .disabled(!presenter.canAddAddOn)
            }
            if let message = presenter.addOnMessage {
                InlineMessage(.info, message)
            }
        } header: {
            Text("Add-on weights")
        } footer: {
            Text("Weights that go on top of the pin, each on or off, such as a 2 kg toggle. A lever with three positions is two equal add-ons.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {

    func editWeightRangeView(router: AnyRouter, delegate: EditWeightRangeDelegate) -> some View {
        EditWeightRangeView(
            presenter: EditWeightRangePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {

    func showEditWeightRangeView(delegate: EditWeightRangeDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editWeightRangeView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    @Previewable @State var stack = WeightStack(
        id: UUID().uuidString, name: "Preview Range", minWeight: 7, maxWeight: 98, increment: 7, unit: .kilograms, isActive: true, addOns: [2, 2]
    )
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = EditWeightRangeDelegate(equipmentName: "Cable Lat Pulldown Machine", range: $stack)

    RouterView { router in
        builder.editWeightRangeView(router: router, delegate: delegate)
    }
}
