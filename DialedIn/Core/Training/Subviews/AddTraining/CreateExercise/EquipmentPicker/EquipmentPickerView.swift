import SwiftUI

struct EquipmentPickerDelegate {
    let items: [AnyEquipment]
    let headerTitle: String
    var chosenItem: Binding<[EquipmentRef]>
    
    init(
        items: [AnyEquipment],
        headerTitle: String = "Equipment",
        chosenItem: Binding<[EquipmentRef]>
    ) {
        self.items = items
        self.headerTitle = headerTitle
        self.chosenItem = chosenItem
    }
}

struct EquipmentPickerView: View {
    
    @State var presenter: EquipmentPickerPresenter
    let delegate: EquipmentPickerDelegate
    @Binding private var chosenItems: [EquipmentRef]
    @State private var searchQuery: String = ""
    
    init(presenter: EquipmentPickerPresenter, delegate: EquipmentPickerDelegate) {
        self.presenter = presenter
        self.delegate = delegate
        self._chosenItems = delegate.chosenItem
    }
    
    var body: some View {
        List {
            equipmentSections
        }
        .navigationTitle(delegate.headerTitle)
        .navigationSubtitle("Choose One")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .searchable(text: $searchQuery, prompt: String(localized: "Filter equipment by name"))
        .toolbar {
            toolbarContent
        }
    }
    
    private var equipmentSections: some View {
        ForEach(sectionedEquipment, id: \.kind) { section in
            Section {
                ForEach(section.items, id: \.self) { item in
                    rowItem(item: item)
                }
            } header: {
                Text(section.kind.sectionTitle)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                presenter.onDismissPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private func rowItem(item: AnyEquipment) -> some View {
        HStack {
            if let imageName = item.imageName {
                ImageLoaderView(urlString: imageName)
                    .frame(width: 40, height: 40)
            } else {
                Rectangle()
                    .foregroundStyle(.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            }

            VStack(alignment: .leading) {
                Text(item.name)
            }
            Spacer()
            Circle()
                .stroke(lineWidth: chosenItems.contains(item.ref) ? 12 : 3)
                .frame(height: 20)
                .labelsHidden()
        }
        .tappableBackground()
        .anyButton(.press) {
            presenter.onSelect(item: item, binding: $chosenItems)
        }
    }
}

private extension EquipmentPickerView {
    struct EquipmentSection: Identifiable {
        let kind: EquipmentKind
        let items: [AnyEquipment]

        var id: EquipmentKind { kind }
    }

    var filteredItems: [AnyEquipment] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return delegate.items }
        return delegate.items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var sectionedEquipment: [EquipmentSection] {
        let groupedItems = Dictionary(grouping: filteredItems, by: { $0.ref.kind })
        let sections = groupedItems.map { kind, items in
            EquipmentSection(
                kind: kind,
                items: items.sorted { lhs, rhs in
                    let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if comparison == .orderedSame {
                        return lhs.ref.id < rhs.ref.id
                    }
                    return comparison == .orderedAscending
                }
            )
        }
        return sections.sorted { lhs, rhs in
            let comparison = lhs.kind.sectionTitle.localizedCaseInsensitiveCompare(rhs.kind.sectionTitle)
            if comparison == .orderedSame {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return comparison == .orderedAscending
        }
    }
}

extension CoreBuilder {
    
    func equipmentPickerView(router: AnyRouter, delegate: EquipmentPickerDelegate) -> some View {
        EquipmentPickerView(
            presenter: EquipmentPickerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showEquipmentPickerView(delegate: EquipmentPickerDelegate) {
        router.showScreen(.sheet) { router in
            builder.equipmentPickerView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = EquipmentPickerDelegate(
        items: GymProfileModel.mock.freeWeights.map(AnyEquipment.init),
        headerTitle: "Free Weights",
        chosenItem: .constant([FreeWeights.mock.equipmentRef])
    )
    
    return RouterView { router in
        builder.equipmentPickerView(router: router, delegate: delegate)
    }
    
}
