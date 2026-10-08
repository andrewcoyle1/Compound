import SwiftUI
import PhotosUI

// MARK: - Active Sorted Weight Subtitle Helper

private enum ActiveSortedWeightSubtitle {
    struct Config<T> {
        let isActive: (T) -> Bool
        let value: (T) -> Double
        let unit: (T) -> ExerciseWeightUnit
        let formatter: (T) -> String
        let separator: String
    }

    static func format<T>(items: [T], config: Config<T>) -> String {
        let sortedItems = items
            .filter(config.isActive)
            .enumerated()
            .sorted { lhs, rhs in
                let lhsValue = UnitConversion.convertWeightToKg(config.value(lhs.element), from: config.unit(lhs.element))
                let rhsValue = UnitConversion.convertWeightToKg(config.value(rhs.element), from: config.unit(rhs.element))
                if lhsValue == rhsValue {
                    return lhs.offset < rhs.offset
                }
                return lhsValue < rhsValue
            }
            .map { $0.element }
        return sortedItems.map(config.formatter).joined(separator: config.separator)
    }
}

struct GymProfileDelegate {
    let onCompleted: (() -> Void)?
    let gymProfile: GymProfileModel
    
    init(onCompleted: (() -> Void)? = nil, gymProfile: GymProfileModel) {
        self.onCompleted = onCompleted
        self.gymProfile = gymProfile
    }
}

struct GymProfileView: View {
    
    @State var presenter: GymProfilePresenter
    let delegate: GymProfileDelegate
    
    var body: some View {
        List {
            imageHeader

            equipmentHeader
            if !presenter.filteredFreeWeights.isEmpty {
                freeWeightsSection
            }

            if !presenter.filteredLoadableBars.isEmpty {
                loadableBarsSection
            }

            if !presenter.filteredFixedWeightBars.isEmpty {
                fixedWeightBarsSection
            }

            if !presenter.filteredBands.isEmpty {
                bandsSection
            }
            
            if !presenter.filteredBodyWeights.isEmpty {
                bodyWeightsSection
            }
            
            if !presenter.filteredSupportEquipment.isEmpty {
                benchesAndRacksSection
            }

            if !presenter.filteredAccessoryEquipment.isEmpty {
                accessoriesSection
            }

            if !presenter.filteredLoadableAccessoryEquipment.isEmpty {
                loadableAccessoriesSection
            }

            if !presenter.filteredCableMachines.isEmpty || !presenter.filteredPlateLoadedMachines.isEmpty || !presenter.filteredPinLoadedMachines.isEmpty {
                GymProfileMachineSectionsView(presenter: $presenter)
            }
            if presenter.hasNoMatchingEquipment {
                ContentUnavailableView.search(text: presenter.searchQuery)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .searchable(text: $presenter.searchQuery, prompt: String(localized: "Filter equipment by name"))
        .toolbar {
            toolbarContent
        }
        .photosPicker(isPresented: $presenter.isImagePickerPresented, selection: $presenter.selectedPhotoItem, matching: .images)
        .onChange(of: presenter.selectedPhotoItem) {
            guard let newItem = presenter.selectedPhotoItem else { return }

            Task {
                await presenter.onImageSelectorChanged(newItem)
            }
        }
        .bottomCTA {
            if delegate.onCompleted != nil {
                CallToActionButton {
                    presenter.onContinuePressed(delegate: delegate)
                } label: {
                    Text("Continue")
                }
            }
        }
    }
    
    private var imageHeader: some View {
        Section {
            ImageLoaderView(
                urlString: presenter.gymProfile.imageUrl ?? Constants.randomImage,
                resizingMode: .fill,
                imageDescription: presenter.gymProfile.imageUrl == nil ? nil : String(localized: "Gym photo")
            )
                .frame(height: 300)
                .removeListRowFormatting()
        }
        .listSectionMargins(.top, 0)
        .listSectionMargins(.horizontal, 0)
    }
    
    private var equipmentHeader: some View {
        Section {
            HStack {
                Text("Equipment")
                    .font(.sectionTitle)
                Spacer()
                Picker("Filter", selection: $presenter.filter) {
                    ForEach(ListFilter.allCases, id: \.self) { option in
                        Text(option.description)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .removeListRowFormatting()
        }
        .listSectionMargins(.vertical, 0)

    }
    
    private var freeWeightsSection: some View {
        Section {
            ForEach(presenter.filteredFreeWeights) { $freeWeight in
                GymEquipmentRow(
                    name: freeWeight.name,
                    imageName: freeWeight.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: freeWeight.range, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.availableWeights },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.weight($0.availableWeights, $0.unit) },
                        separator: ", "
                    )),
                    editTitle: "Edit Weights",
                    isActive: $freeWeight.isActive
                ) {
                    presenter.onEditFreeWeightPressed(freeWeight: $freeWeight)
                }
            }
        } header: {
            Text("Free Weights")
        }
        .listSectionMargins(.top, 0)
    }

    private var loadableBarsSection: some View {
        Section {
            ForEach(presenter.filteredLoadableBars) { $loadableBar in
                GymEquipmentRow(
                    name: loadableBar.name,
                    imageName: loadableBar.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: loadableBar.baseWeights, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.baseWeight },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.weight($0.baseWeight, $0.unit) },
                        separator: ", "
                    )),
                    editTitle: "Edit Weights",
                    isActive: $loadableBar.isActive
                ) {
                    presenter.onEditLoadableBarPressed(loadableBar: $loadableBar)
                }
            }
        } header: {
            Text("Loadable Bars")
        }
    }

    private var fixedWeightBarsSection: some View {
        Section {
            ForEach(presenter.filteredFixedWeightBars) { $fixedWeightBar in
                GymEquipmentRow(
                    name: fixedWeightBar.name,
                    imageName: fixedWeightBar.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: fixedWeightBar.baseWeights, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.baseWeight },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.weight($0.baseWeight, $0.unit) },
                        separator: ", "
                    )),
                    editTitle: "Edit Weights",
                    isActive: $fixedWeightBar.isActive
                ) {
                    presenter.onEditFixedWeightBarPressed(fixedWeightBar: $fixedWeightBar)
                }
            }
        } header: {
            Text("Fixed Weight Bars")
        }
    }

    private var bandsSection: some View {
        Section {
            ForEach(presenter.filteredBands) { $band in
                GymEquipmentRow(
                    name: band.name,
                    imageName: band.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: band.range, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.availableResistance },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.weight($0.availableResistance, $0.unit) },
                        separator: ", "
                    )),
                    editTitle: "Edit Inventory",
                    isActive: $band.isActive
                ) {
                    presenter.onEditBandPressed(band: $band)
                }
            }
        } header: {
            Text("Bands")
        }
    }

    private var bodyWeightsSection: some View {
        Section {
            ForEach(presenter.filteredBodyWeights) { $bodyWeight in
                GymEquipmentRow(
                    name: bodyWeight.name,
                    imageName: bodyWeight.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: bodyWeight.range, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.availableWeights },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.weight($0.availableWeights, $0.unit) },
                        separator: ", "
                    )),
                    editTitle: "Edit Weights",
                    isActive: $bodyWeight.isActive
                ) {
                    presenter.onEditBodyWeightPressed(bodyWeight: $bodyWeight)
                }
            }
        } header: {
            Text("Body Weights")
        }
        .listSectionMargins(.top, 0)
    }

    private var benchesAndRacksSection: some View {
        Section {
            ForEach(presenter.filteredSupportEquipment) { $supportEquipment in
                GymEquipmentRow(name: supportEquipment.name, imageName: supportEquipment.imageName, isActive: $supportEquipment.isActive)
            }
        } header: {
            Text("Benches & Racks")
        }
    }

    private var accessoriesSection: some View {
        Section {
            ForEach(presenter.filteredAccessoryEquipment) { $accessoryEquipment in
                GymEquipmentRow(name: accessoryEquipment.name, imageName: accessoryEquipment.imageName, isActive: $accessoryEquipment.isActive)
            }
        } header: {
            Text("Accessories")
        }
    }

    private var loadableAccessoriesSection: some View {
        Section {
            ForEach(presenter.filteredLoadableAccessoryEquipment) { $loadableAccessoryEquipment in
                GymEquipmentRow(
                    name: loadableAccessoryEquipment.name,
                    imageName: loadableAccessoryEquipment.imageName,
                    detail: GymEquipmentFormat.weight(loadableAccessoryEquipment.baseWeight, loadableAccessoryEquipment.unit),
                    editTitle: "Edit Base Weights",
                    isActive: $loadableAccessoryEquipment.isActive
                ) {
                    presenter.onEditLoadableAccessoryEquipmentPressed(loadableAccessoryEquipment: $loadableAccessoryEquipment)
                }
            }
        } header: {
            Text("Loadable Accessories")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .title) {
            TextField(text: $presenter.gymProfile.name) {
                Text("Untitled Gym Profile")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Add Machine…", systemImage: Symbol.add) {
                    presenter.onAddMachinePressed()
                }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddImagePressed()
            } label: {
                Image(systemName: presenter.gymProfile.imageUrl == nil ? "photo.badge.plus" : "photo.badge.checkmark")
            }
            .accessibilityLabel(presenter.gymProfile.imageUrl == nil ? String(localized: "Add gym photo") : String(localized: "Change gym photo"))
        }
    }

}

// MARK: - Machine Sections (extracted for type_body_length)

private struct GymProfileMachineSectionsView: View {
    @Binding var presenter: GymProfilePresenter

    var body: some View {
        Group {
            if !presenter.filteredCableMachines.isEmpty {
                cableMachinesSection
            }
            if !presenter.filteredPlateLoadedMachines.isEmpty {
                plateLoadedMachineSection
            }
            if !presenter.filteredPinLoadedMachines.isEmpty {
                pinLoadedMachineSection
            }
        }
    }

    private var cableMachinesSection: some View {
        Section {
            ForEach(presenter.filteredCableMachines) { $cableMachines in
                GymEquipmentRow(
                    name: cableMachines.name,
                    imageName: cableMachines.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: cableMachines.ranges, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.lightestPin },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.stack($0) },
                        separator: "\n"
                    )),
                    editTitle: "Edit Machine",
                    isActive: $cableMachines.isActive
                ) {
                    presenter.onEditStackMachinePressed(machine: $cableMachines)
                }
                // One set of actions, so the swipe and the context menu offer the same.
                .rowActions(allowsFullSwipe: false) {
                    machineActions(in: \.cableMachines, machine: cableMachines)
                }
            }
        } header: {
            Text("Cable Machines")
        }
    }

    private var plateLoadedMachineSection: some View {
        Section {
            ForEach(presenter.filteredPlateLoadedMachines) { $plateLoadedMachines in
                GymEquipmentRow(
                    name: plateLoadedMachines.name,
                    imageName: plateLoadedMachines.imageName,
                    detail: plateLoadedMachines.sleeves == 1
                        ? String(localized: "Base \(GymEquipmentFormat.weight(plateLoadedMachines.baseWeight, plateLoadedMachines.unit)) · one side")
                        : GymEquipmentFormat.weight(plateLoadedMachines.baseWeight, plateLoadedMachines.unit),
                    editTitle: "Edit Base Weight",
                    isActive: $plateLoadedMachines.isActive
                ) {
                    presenter.onEditPlateLoadedMachinePressed(plateLoadedMachine: $plateLoadedMachines)
                }
                // One set of actions, so the swipe and the context menu offer the same.
                .rowActions(allowsFullSwipe: false) {
                    machineActions(in: \.plateLoadedMachines, machine: plateLoadedMachines)
                }
            }
        } header: {
            Text("Plate Loaded Machines")
        }
    }

    /// Duplicate for every machine; Delete, last and destructive, only for the user's own and
    /// duplicated ones, since a catalogue machine would come back on the next load.
    @ViewBuilder
    private func machineActions<Machine: CustomizableMachine>(
        in list: WritableKeyPath<GymProfileModel, [Machine]>,
        machine: Machine
    ) -> some View {
        Button {
            presenter.onDuplicateMachinePressed(in: list, id: machine.id)
        } label: {
            Label("Duplicate", systemImage: Symbol.duplicate)
        }
        .tint(.accentColor)
        if machine.isCustom {
            Button(role: .destructive) {
                presenter.onDeleteMachinePressed(machine: machine)
            } label: {
                Label("Delete", systemImage: Symbol.delete)
            }
        }
    }

    private var pinLoadedMachineSection: some View {
        Section {
            ForEach(presenter.filteredPinLoadedMachines) { $pinLoadedMachines in
                GymEquipmentRow(
                    name: pinLoadedMachines.name,
                    imageName: pinLoadedMachines.imageName,
                    detail: ActiveSortedWeightSubtitle.format(items: pinLoadedMachines.ranges, config: .init(
                        isActive: { $0.isActive },
                        value: { $0.lightestPin },
                        unit: { $0.unit },
                        formatter: { GymEquipmentFormat.stack($0) },
                        separator: "\n"
                    )),
                    editTitle: "Edit Machine",
                    isActive: $pinLoadedMachines.isActive
                ) {
                    presenter.onEditStackMachinePressed(machine: $pinLoadedMachines)
                }
                // One set of actions, so the swipe and the context menu offer the same.
                .rowActions(allowsFullSwipe: false) {
                    machineActions(in: \.pinLoadedMachines, machine: pinLoadedMachines)
                }
            }
        } header: {
            Text("Pin Loaded Machines")
        }
    }
}

// MARK: - Equipment Row

/// One piece of equipment: thumbnail, name, what is available, an edit link and the toggle that
/// includes it in this gym. The edit link and the toggle are separate controls in one row, so the
/// link uses `.borderless` to keep the List from turning the whole row into its tap target.
private struct GymEquipmentRow: View {
    let name: String
    let imageName: String?
    var detail: String?
    var editTitle: LocalizedStringKey?
    @Binding var isActive: Bool
    var onEdit: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var thumbnailSide = ControlSize.thumbnail

    var body: some View {
        HStack(spacing: Spacing.m) {
            Group {
                if let imageName {
                    ImageLoaderView(urlString: imageName)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: thumbnailSide, height: thumbnailSide)
            .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(.rowTitle)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let editTitle, let onEdit {
                    Button(action: onEdit) {
                        // Padded to the 44 pt minimum; the text alone was about 20 pt tall.
                        Text(editTitle)
                            .frame(minHeight: ControlSize.row, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .font(.rowDetail.weight(.semibold))
                    .foregroundStyle(.tint)
                    .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $isActive) {
                Text(name)
            }
            .labelsHidden()
        }
    }
}

extension CoreBuilder {
    
    func gymProfileView(router: AnyRouter, delegate: GymProfileDelegate) -> some View {
        GymProfileView(
            presenter: GymProfilePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                gymProfile: delegate.gymProfile
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showGymProfileView(delegate: GymProfileDelegate) {
        router.showScreen(.push) { router in
            builder.gymProfileView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = GymProfileDelegate(gymProfile: GymProfileModel.mock)
    return RouterView { router in
        builder.gymProfileView(router: router, delegate: delegate)
    }
    
}
