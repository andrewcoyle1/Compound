import SwiftUI

@Observable
@MainActor
class EditBodyWeightPresenter {
    
    private let interactor: EditBodyWeightInteractor
    private let router: EditBodyWeightRouter
    
    private let bodyWeightBinding: Binding<BodyWeights>
    var bodyWeight: BodyWeights {
        didSet {
            bodyWeightBinding.wrappedValue = bodyWeight
        }
    }
    var selectedUnit: ExerciseWeightUnit = .kilograms
    
    init(interactor: EditBodyWeightInteractor, router: EditBodyWeightRouter, bodyWeight: Binding<BodyWeights>) {
        self.interactor = interactor
        self.router = router
        self.bodyWeightBinding = bodyWeight
        self.bodyWeight = bodyWeight.wrappedValue
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        bodyWeight.range
            .filter { $0.unit == unit }
            .map { $0.id }
    }
    
    func weightValue(for id: String) -> Double {
        bodyWeight.range.first(where: { $0.id == id })?.availableWeights ?? 0
    }

    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<BodyWeightsAvailable> {
        Binding(
            get: {
                guard let index = self.bodyWeight.range.firstIndex(where: { $0.id == id }) else {
                    return BodyWeightsAvailable(
                        id: id,
                        plateColour: nil,
                        availableWeights: 0,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.bodyWeight.range[index]
            },
            set: { updated in
                guard let index = self.bodyWeight.range.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.bodyWeight.range[index] = updated
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }

        var updated = bodyWeight
        updated.range.removeAll { idsToDelete.contains($0.id) }
        bodyWeight = updated
    }
    
    func onAddPressed() {
        let bodyWeightBinding = Binding(
            get: { self.bodyWeight },
            set: { self.bodyWeight = $0 }
        )
        router.showAddBodyWeightView(delegate: AddBodyWeightDelegate(bodyWeight: bodyWeightBinding, unit: self.selectedUnit))
    }
    
}

extension EditBodyWeightPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditBodyWeightView_Appear"
            case .onDisappear: return "EditBodyWeightView_Disappear"
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
