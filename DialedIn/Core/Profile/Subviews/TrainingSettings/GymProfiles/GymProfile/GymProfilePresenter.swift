import SwiftUI
import PhotosUI

@Observable
@MainActor
class GymProfilePresenter {
    
    private let interactor: GymProfileInteractor
    private let router: GymProfileRouter
    
    var filter: ListFilter = .all
    var gymProfile: GymProfileModel {
        didSet { hasUnsavedChanges = true }
    }
    /// Set by any edit, including the equipment editors' bindings, and cleared by a save.
    private(set) var hasUnsavedChanges = false
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

    private func saveGymProfile(reportFailure: (() -> Void)? = nil, onComplete: @escaping () -> Void) {
        let profile = profileToSave
        hasUnsavedChanges = false
        Task {
            do {
                interactor.trackEvent(event: Event.saveGymProfileStart)
                try await interactor.saveGymProfile(profile: profile, image: nil)
                interactor.trackEvent(event: Event.saveGymProfileSuccess)
                interactor.playHaptic(option: .success)
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
        return sortedIndices.map { index in
            Binding(
                get: { self.gymProfile[keyPath: keyPath][index] },
                set: { self.gymProfile[keyPath: keyPath][index] = $0 }
            )
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
        router.showEditFreeWeightView(freeWeight: freeWeight)
    }

    func onEditLoadableBarPressed(loadableBar: Binding<LoadableBars>) {
        router.showEditLoadableBarView(loadableBar: loadableBar)
    }

    func onEditFixedWeightBarPressed(fixedWeightBar: Binding<FixedWeightBars>) {
        router.showEditFixedWeightBarView(fixedWeightBar: fixedWeightBar)
    }

    func onEditBandPressed(band: Binding<Bands>) {
        router.showEditBandView(band: band)
    }
    
    func onEditBodyWeightPressed(bodyWeight: Binding<BodyWeights>) {
        router.showEditBodyWeightView(bodyWeight: bodyWeight)
    }

    func onEditLoadableAccessoryEquipmentPressed(loadableAccessoryEquipment: Binding<LoadableAccessoryEquipment>) {
        router.showEditLoadableAccessoryView(loadableAccessory: loadableAccessoryEquipment)
    }

    func onEditCableMachinePressed(cableMachine: Binding<CableMachine>) {
        router.showEditCableMachineView(cableMachine: cableMachine)
    }

    func onEditPlateLoadedMachinePressed(plateLoadedMachine: Binding<PlateLoadedMachine>) {
        router.showEditPlateLoadedMachineView(plateLoadedMachine: plateLoadedMachine)
    }

    func onEditPinLoadedMachinePressed(pinLoadedMachine: Binding<PinLoadedMachine>) {
        router.showEditPinLoadedMachineView(pinLoadedMachine: pinLoadedMachine)
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
