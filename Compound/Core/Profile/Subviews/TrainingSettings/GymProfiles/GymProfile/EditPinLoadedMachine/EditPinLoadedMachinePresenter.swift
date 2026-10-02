import SwiftUI

@Observable
@MainActor
class EditPinLoadedMachinePresenter {
    
    private let interactor: EditPinLoadedMachineInteractor
    private let router: EditPinLoadedMachineRouter
    
    private let pinLoadedMachineBinding: Binding<PinLoadedMachine>
    var pinLoadedMachine: PinLoadedMachine {
        didSet {
            pinLoadedMachineBinding.wrappedValue = pinLoadedMachine
        }
    }
    var selectedUnit: ExerciseWeightUnit
    
    init(interactor: EditPinLoadedMachineInteractor, router: EditPinLoadedMachineRouter, pinLoadedMachineBinding: Binding<PinLoadedMachine>) {
        self.interactor = interactor
        self.router = router
        self.pinLoadedMachineBinding = pinLoadedMachineBinding
        self.pinLoadedMachine = pinLoadedMachineBinding.wrappedValue
        self.selectedUnit = pinLoadedMachineBinding.wrappedValue.defaultRange?.unit ?? .kilograms
    }
        
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        pinLoadedMachine.ranges
            .filter { $0.unit == unit }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            }
            .map { $0.id }
    }
    
    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<PinLoadedMachineRange> {
        Binding(
            get: {
                guard let index = self.pinLoadedMachine.ranges.firstIndex(where: { $0.id == id }) else {
                    return PinLoadedMachineRange(
                        id: id,
                        name: "Custom Range",
                        minWeight: 0,
                        maxWeight: 150,
                        increment: 2.5,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.pinLoadedMachine.ranges[index]
            },
            set: { updated in
                guard let index = self.pinLoadedMachine.ranges.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.pinLoadedMachine.ranges[index] = updated
            }
        )
    }
    
    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }
        
        var updated = pinLoadedMachine
        updated.ranges.removeAll { idsToDelete.contains($0.id) }
        pinLoadedMachine = updated
    }
    
    func onEditRangePressed(range: Binding<PinLoadedMachineRange>) {
        router.showEditWeightRangeView(delegate: EditWeightRangeDelegate(equipmentName: pinLoadedMachine.name, range: range))
    }
    
    func onAddPressed() {
        let pinLoadedMachineBinding = Binding(
            get: { self.pinLoadedMachine },
            set: { self.pinLoadedMachine = $0 }
        )
        router.showAddPinLoadedMachineRangeView(
            delegate: AddPinLoadedMachineRangeDelegate(
                pinLoadedMachine: pinLoadedMachineBinding,
                unit: selectedUnit
            )
        )
    }
}

extension EditPinLoadedMachinePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditPinLoadedMachineView_Appear"
            case .onDisappear: return "EditPinLoadedMachineView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
