import SwiftUI

struct EnumPickerDelegate<Item: PickableItem> {
    let navigationTitle: String
    var chosenItem: Binding<Item?>
    var canDelete: Bool
}

protocol PickableItem: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var name: String { get }
    var description: String? { get }
}

struct EnumPickerView<Item: PickableItem>: View {
    
    @State var presenter: EnumPickerPresenter
    let delegate: EnumPickerDelegate<Item>
    
    var body: some View {
        List {
            pickerSection
        }
        .navigationTitle(delegate.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar { toolbarContent }
        .scrollIndicators(.hidden)
    }

    private var pickerSection: some View {
        Section {
            ForEach(Array(Item.allCases), id: \.self) { item in
                rowItem(item: item)
            }
        }
        .listSectionMargins(.top, 0)
    }
    
    func rowItem(item: Item) -> some View {
        SelectableRow(title: item.name, subtitle: item.description, isSelected: delegate.chosenItem.wrappedValue == item) {
            presenter.onSelect(item: item, binding: delegate.chosenItem)
        }
        .accessibilityIdentifier("EnumPicker.\(item.name)")
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        if delegate.canDelete {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presenter.onDeletePressed(binding: delegate.chosenItem)
                } label: {
                    Image(systemName: Symbol.delete)
                }
                .accessibilityLabel("Clear selection")
            }
        }
    }
}

extension CoreBuilder {
    
    func enumPickerView<Item: PickableItem>(router: AnyRouter, delegate: EnumPickerDelegate<Item>) -> some View {
        EnumPickerView<Item>(
            presenter: EnumPickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showEnumPickerView<Item: PickableItem>(delegate: EnumPickerDelegate<Item>, detentsInput: PresentationDetentTransformable? = nil) {
        if let detentsVerified = detentsInput {
            // Always offers `.large` too, so the list is never trapped at large Dynamic Type sizes.
            router.showScreen(.sheetConfig(config: ResizableSheetConfig(
                detents: [detentsVerified, .large],
                dragIndicator: .visible
            ))) { router in
                builder.enumPickerView(router: router, delegate: delegate)
            }
        } else {
            router.showScreen(.sheet) { router in
                builder.enumPickerView(router: router, delegate: delegate)
            }
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = EnumPickerDelegate<TrackableExerciseMetric>(
        navigationTitle: "Trackable Metric 1",
        chosenItem: .constant(TrackableExerciseMetric.reps),
        canDelete: true
    )
    
    return RouterView { router in
        builder.enumPickerView(router: router, delegate: delegate)
    }
}
