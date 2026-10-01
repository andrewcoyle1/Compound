import SwiftUI

@Observable
@MainActor
class EditCableMachinePresenter {
    
    private let interactor: EditCableMachineInteractor
    private let router: EditCableMachineRouter
    
    private let cableMachineBinding: Binding<CableMachine>
    var cableMachine: CableMachine {
        didSet {
            cableMachineBinding.wrappedValue = cableMachine
        }
    }
    var selectedUnit: ExerciseWeightUnit

    init(interactor: EditCableMachineInteractor, router: EditCableMachineRouter, cableMachineBinding: Binding<CableMachine>) {
        self.interactor = interactor
        self.router = router
        self.cableMachineBinding = cableMachineBinding
        self.cableMachine = cableMachineBinding.wrappedValue
        self.selectedUnit = cableMachineBinding.wrappedValue.defaultRange?.unit ?? .kilograms
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        cableMachine.ranges
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

    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<CableMachineRange> {
        Binding(
            get: {
                guard let index = self.cableMachine.ranges.firstIndex(where: { $0.id == id }) else {
                    return CableMachineRange(
                        id: id,
                        name: "Custom Range",
                        minWeight: 0,
                        maxWeight: 120,
                        increment: 2.5,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.cableMachine.ranges[index]
            },
            set: { updated in
                guard let index = self.cableMachine.ranges.firstIndex(where: { $0.id == id }) else {
                    return
                }
                var updatedMachine = self.cableMachine
                updatedMachine.ranges[index] = updated
                self.cableMachine = updatedMachine
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }

        var updated = cableMachine
        updated.ranges.removeAll { idsToDelete.contains($0.id) }
        cableMachine = updated
    }
    
    func onEditRangePressed(range: Binding<CableMachineRange>) {
        router.showEditWeightRangeView(delegate: EditWeightRangeDelegate(equipmentName: cableMachine.name, range: range))
    }
    
    func onAddPressed() {
        let cableMachineBinding = Binding(
            get: { self.cableMachine },
            set: { self.cableMachine = $0 }
        )
        router.showAddCableMachineRangeView(
            delegate: AddCableMachineRangeDelegate(
                cableMachine: cableMachineBinding,
                unit: selectedUnit
            )
        )
    }
    
}

extension EditCableMachinePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditCableMachineView_Appear"
            case .onDisappear: return "EditCableMachineView_Disappear"
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
