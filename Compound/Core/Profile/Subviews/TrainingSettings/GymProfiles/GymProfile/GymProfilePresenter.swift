import SwiftUI
import PhotosUI

@Observable
@MainActor
class GymProfilePresenter {
    
    private let interactor: GymProfileInteractor
    private let router: GymProfileRouter
    
    var filter: ListFilter = .all
    var gymProfile: GymProfileModel {
        didSet {
            hasUnsavedChanges = true
            if isEditorPushed { scheduleSaveWhileCovered() }
        }
    }
    /// Set by any edit, including the equipment editors' bindings, and cleared by a save.
    private(set) var hasUnsavedChanges = false
    /// An equipment editor is pushed over this screen. This screen's `onDisappear` ran when the
    /// editor was pushed, and does not run again if the whole Profile sheet is swiped away from
    /// the editor, so edits made there save as they happen.
    private(set) var isEditorPushed = false
    private var coveredSave: Task<Void, Never>?
    var searchQuery: String = ""

    var selectedPhotoItem: PhotosPickerItem?
    var selectedImageData: Data?
    var isImagePickerPresented: Bool = false

    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(interactor: GymProfileInteractor, router: GymProfileRouter, gymProfile: GymProfileModel) {
        self.interactor = interactor
        self.router = router
        self.gymProfile = gymProfile
    }
    
    func onViewAppear() {
        isEditorPushed = false
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    /// Leaving saves. The screen uses the system back button, and it is pushed inside the Profile
    /// sheet, so Back, the edge swipe and swiping the sheet away all end here. Saving only from a
    /// custom Back button lost every edit made before the sheet was swiped down.
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
        guard hasUnsavedChanges else { return }
        saveGymProfile(reportFailure: { [interactor] in
            // The screen is gone, so an alert would have nowhere to show.
            interactor.showAppToast(AppToast(style: .failure, message: String(localized: "Unable to save gym profile")))
        }, onComplete: { })
    }

    var filteredFreeWeights: [Binding<FreeWeights>] {
        filteredBindings(for: \.freeWeights)
    }

    var filteredLoadableBars: [Binding<LoadableBars>] {
        filteredBindings(for: \.loadableBars)
    }

    var filteredFixedWeightBars: [Binding<FixedWeightBars>] {
        filteredBindings(for: \.fixedWeightBars)
    }

    var filteredBands: [Binding<Bands>] {
        filteredBindings(for: \.bands)
    }
    
    var filteredBodyWeights: [Binding<BodyWeights>] {
        filteredBindings(for: \.bodyWeights)
    }

    var filteredSupportEquipment: [Binding<SupportEquipment>] {
        filteredBindings(for: \.supportEquipment)
    }

    var filteredAccessoryEquipment: [Binding<AccessoryEquipment>] {
        filteredBindings(for: \.accessoryEquipment)
    }
    
    var filteredLoadableAccessoryEquipment: [Binding<LoadableAccessoryEquipment>] {
        filteredBindings(for: \.loadableAccessoryEquipment)
    }

    var filteredCableMachines: [Binding<CableMachine>] {
        filteredBindings(for: \.cableMachines)
    }

    var filteredPlateLoadedMachines: [Binding<PlateLoadedMachine>] {
        filteredBindings(for: \.plateLoadedMachines)
    }

    var filteredPinLoadedMachines: [Binding<PinLoadedMachine>] {
        filteredBindings(for: \.pinLoadedMachines)
    }

    /// A filter that hides every section, so the screen can say so instead of going blank.
    var hasNoMatchingEquipment: Bool {
        !trimmedSearchQuery.isEmpty
            && filteredFreeWeights.isEmpty && filteredLoadableBars.isEmpty && filteredFixedWeightBars.isEmpty
            && filteredBands.isEmpty && filteredBodyWeights.isEmpty && filteredSupportEquipment.isEmpty
            && filteredAccessoryEquipment.isEmpty && filteredLoadableAccessoryEquipment.isEmpty
            && filteredCableMachines.isEmpty && filteredPlateLoadedMachines.isEmpty && filteredPinLoadedMachines.isEmpty
    }
    
    /// A profile left without a name is saved under the name its title field shows as a
    /// placeholder, rather than thrown away.
    private var profileToSave: GymProfileModel {
        var profile = gymProfile
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.name = String(localized: "Untitled Gym Profile")
        }
        profile.dateModified = .now
        return profile
    }

    /// Debounced, so switching several weights on in a row writes once.
    private func scheduleSaveWhileCovered() {
        coveredSave?.cancel()
        coveredSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled, self.hasUnsavedChanges else { return }
            self.saveGymProfile(confirms: false, reportFailure: { [interactor] in
                interactor.showAppToast(AppToast(style: .failure, message: String(localized: "Unable to save gym profile")))
            }, onComplete: { })
        }
    }

    /// `confirms: false` skips the success haptic, for saves the person did not ask for by leaving.
    private func saveGymProfile(confirms: Bool = true, reportFailure: (() -> Void)? = nil, onComplete: @escaping () -> Void) {
        let profile = profileToSave
        hasUnsavedChanges = false
        Task {
            do {
                interactor.trackEvent(event: Event.saveGymProfileStart)
                try await interactor.saveGymProfile(profile: profile, image: nil)
                interactor.trackEvent(event: Event.saveGymProfileSuccess)
                if confirms { interactor.playHaptic(option: .success) }
                onComplete()
            } catch {
                hasUnsavedChanges = true
                interactor.trackEvent(event: Event.saveGymProfileFail(error: error))
                interactor.playHaptic(option: .error)
                if let reportFailure {
                    reportFailure()
                } else {
                    // `onComplete` is what moves on from this screen, so a silent failure leaves
                    // Continue looking broken. Say why nothing moved.
                    router.showSimpleAlert(
                        title: String(localized: "Unable to Save Gym Profile"),
                        subtitle: String(localized: "Please check your internet connection and try again.")
                    )
                }
            }
        }
    }

    private func sortedIndicesByName<T: GymEquipmentItem>(
        items: [T],
        indices: [Int]
    ) -> [Int] {
        indices.sorted { lhs, rhs in
            let lhsName = items[lhs].name
            let rhsName = items[rhs].name
            let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if comparison == .orderedSame {
                return lhs < rhs
            }
            return comparison == .orderedAscending
        }
    }

    private func filteredBindings<T: GymEquipmentItem>(
        for keyPath: WritableKeyPath<GymProfileModel, [T]>
    ) -> [Binding<T>] {
        let query = trimmedSearchQuery
        let items = gymProfile[keyPath: keyPath]
        let indices = items.indices.filter {
            let item = items[$0]
            let matchesQuery = query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
            let matchesFilter = filter == .all || item.isActive
            return matchesQuery && matchesFilter
        }
        let sortedIndices = sortedIndicesByName(items: items, indices: indices)
        return sortedIndices.map { binding(for: keyPath, id: items[$0].id, fallback: items[$0]) }
    }

    /// Follows the item by id rather than position, since machines can now be inserted and
    /// deleted: a row mid-removal reads as it last was, and writing to it changes nothing.
    private func binding<T: GymEquipmentItem>(
        for keyPath: WritableKeyPath<GymProfileModel, [T]>,
        id: String,
        fallback: T
    ) -> Binding<T> {
        Binding(
            get: { self.gymProfile[keyPath: keyPath].first { $0.id == id } ?? fallback },
            set: { updated in
                guard let index = self.gymProfile[keyPath: keyPath].firstIndex(where: { $0.id == id }) else { return }
                self.gymProfile[keyPath: keyPath][index] = updated
            }
        )
    }

    // MARK: Machines

    /// A second machine of the same type, such as another lat pulldown, which the user can then
    /// rename and set up. Nothing opens: the copy appears beside the original.
    func onDuplicateMachinePressed<Machine: CustomizableMachine>(in list: WritableKeyPath<GymProfileModel, [Machine]>, id: String) {
        guard gymProfile.duplicateMachine(in: list, id: id) != nil else { return }
        interactor.playHaptic(option: .success)
    }

    func onDeleteMachinePressed<Machine: CustomizableMachine>(machine: Machine) {
        guard machine.isCustom else { return }
        let id = machine.id
        let kind = Machine.kind
        router.showAlert(
            title: String(localized: "Delete Machine?"),
            subtitle: String(localized: "\(machine.name) will be removed from this gym."),
            buttons: {
                AnyView(
                    Group {
                        Button("Delete", role: .destructive) {
                            self.deleteMachine(kind: kind, id: id)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func deleteMachine(kind: EquipmentKind, id: String) {
        gymProfile.deleteMachine(kind: kind, id: id)
    }

    func onAddMachinePressed() {
        router.showAddGymMachineView(delegate: AddGymMachineDelegate { [weak self] draft in
            self?.addMachine(draft)
        })
    }

    /// Adds the machine and opens its editor, where its stacks or base weight are set up.
    func addMachine(_ draft: GymMachineDraft) {
        guard let id = gymProfile.addMachine(kind: draft.kind, name: draft.name, worksAs: draft.worksAs) else { return }
        switch draft.kind {
        case .cableMachine:
            guard let machine = gymProfile.cableMachines.first(where: { $0.id == id }) else { return }
            onEditStackMachinePressed(machine: binding(for: \.cableMachines, id: id, fallback: machine))
        case .pinLoadedMachine:
            guard let machine = gymProfile.pinLoadedMachines.first(where: { $0.id == id }) else { return }
            onEditStackMachinePressed(machine: binding(for: \.pinLoadedMachines, id: id, fallback: machine))
        case .plateLoadedMachine:
            guard let machine = gymProfile.plateLoadedMachines.first(where: { $0.id == id }) else { return }
            onEditPlateLoadedMachinePressed(plateLoadedMachine: binding(for: \.plateLoadedMachines, id: id, fallback: machine))
        default:
            break
        }
    }
        
    func onContinuePressed(delegate: GymProfileDelegate) {
        saveGymProfile {
            Task {
                self.interactor.trackEvent(event: Event.favouriteGymProfileStart)
                do {
                    try await self.interactor.updateFavouriteGymProfileId(profileId: self.gymProfile.id)
                    self.interactor.trackEvent(event: Event.favouriteGymProfileSuccess)
                } catch {
                    self.interactor.trackEvent(event: Event.favouriteGymProfileFail(error: error))
                }
                self.handleNavigation()
            }
        }
    }
    
    func onEditFreeWeightPressed(freeWeight: Binding<FreeWeights>) {
        isEditorPushed = true
        router.showEditFreeWeightView(freeWeight: freeWeight)
    }

    func onEditLoadableBarPressed(loadableBar: Binding<LoadableBars>) {
        isEditorPushed = true
        router.showEditLoadableBarView(loadableBar: loadableBar)
    }

    func onEditFixedWeightBarPressed(fixedWeightBar: Binding<FixedWeightBars>) {
        isEditorPushed = true
        router.showEditFixedWeightBarView(fixedWeightBar: fixedWeightBar)
    }

    func onEditBandPressed(band: Binding<Bands>) {
        isEditorPushed = true
        router.showEditBandView(band: band)
    }
    
    func onEditBodyWeightPressed(bodyWeight: Binding<BodyWeights>) {
        isEditorPushed = true
        router.showEditBodyWeightView(bodyWeight: bodyWeight)
    }

    func onEditLoadableAccessoryEquipmentPressed(loadableAccessoryEquipment: Binding<LoadableAccessoryEquipment>) {
        router.showEditLoadableAccessoryView(loadableAccessory: loadableAccessoryEquipment)
    }

    func onEditStackMachinePressed<Machine: StackMachine>(machine: Binding<Machine>) {
        isEditorPushed = true
        router.showEditStackMachineView(machine: machine)
    }

    func onEditPlateLoadedMachinePressed(plateLoadedMachine: Binding<PlateLoadedMachine>) {
        router.showEditPlateLoadedMachineView(plateLoadedMachine: plateLoadedMachine)
    }
    
    func onAddImagePressed() {
        isImagePickerPresented = true
    }
    
    func onImageSelectorChanged(_ newItem: PhotosPickerItem) async {
        interactor.trackEvent(event: Event.imageSelectorStart)
        do {
            if let data = try await newItem.loadTransferable(type: Data.self) {
                selectedImageData = data
                let uiImage = selectedImageData.flatMap { UIImage(data: $0) }
                let profile = profileToSave
                hasUnsavedChanges = false
                try await interactor.saveGymProfile(profile: profile, image: uiImage)
                interactor.trackEvent(event: Event.imageSelectorSuccess)
            } else {
                interactor.trackEvent(event: Event.imageSelectorCancel)
            }
        } catch {
            await MainActor.run {
                interactor.trackEvent(event: Event.imageSelectorFail(error: error))
            }
        }
    }
    
    // MARK: Handle Navigation
    func handleNavigation() {
        // Navigate based on user's inferred onboarding step
        if let currentUser = interactor.currentUser {
            let step = currentUser.inferredOnboardingStep
            route(to: step)
        }
    }

    private func route(to step: OnboardingStep) {
        router.routeToOnboardingStep(step, onComplete: handleNavigation)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveGymProfileStart
        case saveGymProfileSuccess
        case saveGymProfileFail(error: Error)
        case imageSelectorStart
        case imageSelectorSuccess
        case imageSelectorCancel
        case imageSelectorFail(error: Error)
        case favouriteGymProfileStart
        case favouriteGymProfileSuccess
        case favouriteGymProfileFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "GymProfileView_OnAppear"
            case .onDisappear:              return "GymProfileView_OnDisappear"
            case .saveGymProfileStart:      return "GymProfileView_Save_Start"
            case .saveGymProfileSuccess:    return "GymProfileView_Save_Success"
            case .saveGymProfileFail:       return "GymProfileView_Save_Fail"
            case .imageSelectorStart:       return "GymProfileView_ImageSelected_Start"
            case .imageSelectorSuccess:     return "GymProfileView_ImageSelected_Success"
            case .imageSelectorFail:        return "GymProfileView_ImageSelected_Fail"
            case .imageSelectorCancel:      return "GymProfileView_ImageSelected_Cancel"
            case .favouriteGymProfileStart:     return "GymProfileView_FavouriteGymProfile_Start"
            case .favouriteGymProfileSuccess:   return "GymProfileView_FavouriteGymProfile_Success"
            case .favouriteGymProfileFail:      return "GymProfileView_FavouriteGymProfile_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveGymProfileFail(error: let error), .imageSelectorFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveGymProfileFail, .imageSelectorFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}

enum ListFilter: CaseIterable {
    case all
    case selected
    
    var description: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .selected:
            return String(localized: "Selected")
        }
    }
}
