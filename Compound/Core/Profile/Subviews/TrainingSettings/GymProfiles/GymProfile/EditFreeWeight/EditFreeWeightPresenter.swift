import SwiftUI

@Observable
@MainActor
class EditFreeWeightPresenter {
    
    private let interactor: EditFreeWeightInteractor
    private let router: EditFreeWeightRouter
    
    private let freeWeightBinding: Binding<FreeWeights>
    var freeWeight: FreeWeights {
        didSet {
            freeWeightBinding.wrappedValue = freeWeight
        }
    }
    var selectedUnit: ExerciseWeightUnit = .kilograms
    
    init(interactor: EditFreeWeightInteractor, router: EditFreeWeightRouter, freeWeight: Binding<FreeWeights>) {
        self.interactor = interactor
        self.router = router
        self.freeWeightBinding = freeWeight
        self.freeWeight = freeWeight.wrappedValue
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        freeWeight.range
            .filter { $0.unit == unit }
            .map { $0.id }
    }

    func weightValue(for id: String) -> Double {
        freeWeight.range.first(where: { $0.id == id })?.availableWeights ?? 0
    }

    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<FreeWeightsAvailable> {
        Binding(
            get: {
                guard let index = self.freeWeight.range.firstIndex(where: { $0.id == id }) else {
                    return FreeWeightsAvailable(
                        id: id,
                        plateColour: nil,
                        availableWeights: 0,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.freeWeight.range[index]
            },
            set: { updated in
                guard let index = self.freeWeight.range.firstIndex(where: { $0.id == id }) else {
                    return
                }
                var nextFreeWeight = self.freeWeight
                nextFreeWeight.range[index] = updated
                self.freeWeight = nextFreeWeight
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }

        var updated = freeWeight
        updated.range.removeAll { idsToDelete.contains($0.id) }
        freeWeight = updated
    }
    
    func onAddPressed() {
        let freeWeightBinding = Binding(
            get: { self.freeWeight },
            set: { self.freeWeight = $0 }
        )
        router.showAddFreeWeightView(delegate: AddFreeWeightDelegate(freeWeight: freeWeightBinding, unit: self.selectedUnit))
    }
}

extension EditFreeWeightPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditFreeWeightView_Appear"
            case .onDisappear: return "EditFreeWeightView_Disappear"
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
