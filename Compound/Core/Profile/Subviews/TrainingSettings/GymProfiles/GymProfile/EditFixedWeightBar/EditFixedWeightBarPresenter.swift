import SwiftUI

@Observable
@MainActor
class EditFixedWeightBarPresenter {
    
    private let interactor: EditFixedWeightBarInteractor
    private let router: EditFixedWeightBarRouter
    
    private let fixedWeightBarBinding: Binding<FixedWeightBars>
    var fixedWeightBar: FixedWeightBars {
        didSet {
            fixedWeightBarBinding.wrappedValue = fixedWeightBar
        }
    }
    var selectedUnit: ExerciseWeightUnit
    
    init(interactor: EditFixedWeightBarInteractor, router: EditFixedWeightBarRouter, fixedWeightBarBinding: Binding<FixedWeightBars>) {
        self.interactor = interactor
        self.router = router
        self.fixedWeightBarBinding = fixedWeightBarBinding
        self.fixedWeightBar = fixedWeightBarBinding.wrappedValue
        self.selectedUnit = fixedWeightBarBinding.wrappedValue.defaultBaseWeight?.unit ?? .kilograms
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        fixedWeightBar.baseWeights
            .filter { $0.unit == unit }
            .map { $0.id }
    }
    
    func weightValue(for id: String) -> Double {
        fixedWeightBar.baseWeights.first(where: { $0.id == id })?.baseWeight ?? 0
    }

    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<FixedWeightBarsBaseWeight> {
        Binding(
            get: {
                guard let index = self.fixedWeightBar.baseWeights.firstIndex(where: { $0.id == id }) else {
                    return FixedWeightBarsBaseWeight(
                        id: id,
                        baseWeight: 0,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.fixedWeightBar.baseWeights[index]
            },
            set: { updated in
                guard let index = self.fixedWeightBar.baseWeights.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.fixedWeightBar.baseWeights[index] = updated
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }

        var updated = fixedWeightBar
        updated.baseWeights.removeAll { idsToDelete.contains($0.id) }
        fixedWeightBar = updated
    }
    
    func onAddPressed() {
        let fixedWeightBarBinding = Binding(
            get: { self.fixedWeightBar },
            set: { self.fixedWeightBar = $0 }
        )

        router.showAddFixedWeightBarView(delegate: AddFixedWeightBarDelegate(fixedWeightBar: fixedWeightBarBinding, unit: selectedUnit))
    }
    
}

extension EditFixedWeightBarPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditFixedWeightBarView_Appear"
            case .onDisappear: return "EditFixedWeightBarView_Disappear"
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
