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
        .navigationBarBackButtonHidden(true)
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
        .safeAreaInset(edge: .bottom) {
            if delegate.onCompleted != nil {
                CallToActionButton {
                    presenter.onContinuePressed(delegate: delegate)
                } label: {
                    Text("Continue")
                }
                .padding(.bottom)
            }
        }
    }
    
    private var imageHeader: some View {
        Section {
            ImageLoaderView(urlString: presenter.gymProfile.imageUrl ?? Constants.randomImage, resizingMode: .fill)
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
                    .font(.headline)
                Spacer()
                Picker("", selection: $presenter.filter) {
                    ForEach(ListFilter.allCases, id: \.self) { option in
                        Text(option.description)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }
            .removeListRowFormatting()
        }
        .listSectionMargins(.vertical, 0)

    }
    
    private var freeWeightsSection: some View {
        Section {
            if presenter.filteredFreeWeights.isEmpty {
                ContentUnavailableView("No Weights", image: "dumbbell", description: Text("There are no weights added to this gym."))
            } else {
                ForEach(presenter.filteredFreeWeights) { $freeWeight in
                    HStack {
                        if let imageName = freeWeight.imageName {
                            ImageLoaderView(urlString: imageName)
                                .frame(width: 40, height: 40)
                        } else {
                            Rectangle()
                                .foregroundStyle(.secondary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading) {
                            Text(freeWeight.name)
                            Text(ActiveSortedWeightSubtitle.format(items: freeWeight.range, config: .init(
                                isActive: { $0.isActive },
                                value: { $0.availableWeights },
                                unit: { $0.unit },
                                formatter: { "\(String(format: "%g", $0.availableWeights)) \($0.unit.abbreviation)" },
                                separator: ", "
                            )))
                                .font(.caption)
                                .lineLimit(2)
                            Text("Edit Weights")
                                .underline()
                                .font(.caption.bold())
                                .anyButton {
                                    presenter.onEditFreeWeightPressed(freeWeight: $freeWeight)
                                }
                        }
                        Spacer()
                        Toggle("", isOn: $freeWeight.isActive)
                            .labelsHidden()
                    }
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
                HStack {
                    if let imageName = loadableBar.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(loadableBar.name)
                        Text(ActiveSortedWeightSubtitle.format(items: loadableBar.baseWeights, config: .init(
                            isActive: { $0.isActive },
                            value: { $0.baseWeight },
                            unit: { $0.unit },
                            formatter: { "\(String(format: "%g", $0.baseWeight)) \($0.unit.abbreviation)" },
                            separator: ", "
                        )))
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Weights")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditLoadableBarPressed(loadableBar: $loadableBar)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $loadableBar.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Loadable Bars")
        }
    }

    private var fixedWeightBarsSection: some View {
        Section {
            ForEach(presenter.filteredFixedWeightBars) { $fixedWeightBar in
                HStack {
                    if let imageName = fixedWeightBar.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(fixedWeightBar.name)
                        Text(ActiveSortedWeightSubtitle.format(items: fixedWeightBar.baseWeights, config: .init(
                            isActive: { $0.isActive },
                            value: { $0.baseWeight },
                            unit: { $0.unit },
                            formatter: { "\(String(format: "%g", $0.baseWeight)) \($0.unit.abbreviation)" },
                            separator: ", "
                        )))
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Weights")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditFixedWeightBarPressed(fixedWeightBar: $fixedWeightBar)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $fixedWeightBar.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Fixed Weight Bars")
        }
    }

    private var bandsSection: some View {
        Section {
            ForEach(presenter.filteredBands) { $band in
                HStack {
                    if let imageName = band.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(band.name)
                        Text(ActiveSortedWeightSubtitle.format(items: band.range, config: .init(
                            isActive: { $0.isActive },
                            value: { $0.availableResistance },
                            unit: { $0.unit },
                            formatter: { "\(String(format: "%g", $0.availableResistance)) \($0.unit.abbreviation)" },
                            separator: ", "
                        )))
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Inventory")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditBandPressed(band: $band)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $band.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Bands")
        }
    }
    
    private var bodyWeightsSection: some View {
        Section {
            if presenter.filteredBodyWeights.isEmpty {
                ContentUnavailableView("No Weights", image: "dumbbell", description: Text("There are no weights added to this gym."))
            } else {
                ForEach(presenter.filteredBodyWeights) { $bodyWeight in
                    HStack {
                        if let imageName = bodyWeight.imageName {
                            ImageLoaderView(urlString: imageName)
                                .frame(width: 40, height: 40)
                        } else {
                            Rectangle()
                                .foregroundStyle(.secondary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading) {
                            Text(bodyWeight.name)
                            Text(ActiveSortedWeightSubtitle.format(items: bodyWeight.range, config: .init(
                                isActive: { $0.isActive },
                                value: { $0.availableWeights },
                                unit: { $0.unit },
                                formatter: { "\(String(format: "%g", $0.availableWeights)) \($0.unit.abbreviation)" },
                                separator: ", "
                            )))
                                .font(.caption)
                                .lineLimit(2)
                            Text("Edit Weights")
                                .underline()
                                .font(.caption.bold())
                                .anyButton {
                                    presenter.onEditBodyWeightPressed(bodyWeight: $bodyWeight)
                                }
                        }
                        Spacer()
                        Toggle("", isOn: $bodyWeight.isActive)
                            .labelsHidden()
                    }
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
                HStack {
                    if let imageName = supportEquipment.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(supportEquipment.name)
                    }
                    Spacer()
                    Toggle("", isOn: $supportEquipment.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Benches & Racks")
        }
    }

    private var accessoriesSection: some View {
        Section {
            ForEach(presenter.filteredAccessoryEquipment) { $accessoryEquipment in
                HStack {
                    if let imageName = accessoryEquipment.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(accessoryEquipment.name)
                    }
                    Spacer()
                    Toggle("", isOn: $accessoryEquipment.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Accessories")
        }
    }

    private var loadableAccessoriesSection: some View {
        Section {
            ForEach(presenter.filteredLoadableAccessoryEquipment) { $loadableAccessoryEquipment in
                HStack {
                    if let imageName = loadableAccessoryEquipment.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(loadableAccessoryEquipment.name)
                        Text("\(String(format: "%g", loadableAccessoryEquipment.baseWeight)) \(loadableAccessoryEquipment.unit.abbreviation)")
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Base Weights")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditLoadableAccessoryEquipmentPressed(loadableAccessoryEquipment: $loadableAccessoryEquipment)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $loadableAccessoryEquipment.isActive)
                        .labelsHidden()
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
        
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presenter.onBackButtonPressed()
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back")
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
                HStack {
                    if let imageName = cableMachines.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(cableMachines.name)
                        Text(ActiveSortedWeightSubtitle.format(items: cableMachines.ranges, config: .init(
                            isActive: { $0.isActive },
                            value: { $0.minWeight },
                            unit: { $0.unit },
                            formatter: {
                                String(localized: "\(String(format: "%g", $0.minWeight)) - \(String(format: "%g", $0.maxWeight)) \(String(describing: $0.unit.abbreviation)), \(String(format: "%g", $0.increment)) \(String(describing: $0.unit.abbreviation)) increments")
                            },
                            separator: "\n"
                        )))
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Machine")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditCableMachinePressed(cableMachine: $cableMachines)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $cableMachines.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Cable Machines")
        }
    }

    private var plateLoadedMachineSection: some View {
        Section {
            ForEach(presenter.filteredPlateLoadedMachines) { $plateLoadedMachines in
                HStack {
                    if let imageName = plateLoadedMachines.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(plateLoadedMachines.name)
                        Text("\(String(format: "%g", plateLoadedMachines.baseWeight)) \(plateLoadedMachines.unit.abbreviation)")
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Base Weight")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditPlateLoadedMachinePressed(plateLoadedMachine: $plateLoadedMachines)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $plateLoadedMachines.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Plate Loaded Machines")
        }
    }

    private var pinLoadedMachineSection: some View {
        Section {
            ForEach(presenter.filteredPinLoadedMachines) { $pinLoadedMachines in
                HStack {
                    if let imageName = pinLoadedMachines.imageName {
                        ImageLoaderView(urlString: imageName)
                            .frame(width: 40, height: 40)
                    } else {
                        Rectangle()
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(pinLoadedMachines.name)
                        Text(ActiveSortedWeightSubtitle.format(items: pinLoadedMachines.ranges, config: .init(
                            isActive: { $0.isActive },
                            value: { $0.minWeight },
                            unit: { $0.unit },
                            formatter: {
                                String(localized: "\(String(format: "%g", $0.minWeight)) - \(String(format: "%g", $0.maxWeight)) \(String(describing: $0.unit.abbreviation)), \(String(format: "%g", $0.increment)) \(String(describing: $0.unit.abbreviation)) increments")
                            },
                            separator: "\n"
                        )))
                            .font(.caption)
                            .lineLimit(2)
                        Text("Edit Machine")
                            .underline()
                            .font(.caption.bold())
                            .anyButton {
                                presenter.onEditPinLoadedMachinePressed(pinLoadedMachine: $pinLoadedMachines)
                            }

                    }
                    Spacer()
                    Toggle("", isOn: $pinLoadedMachines.isActive)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Pin Loaded Machines")
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
