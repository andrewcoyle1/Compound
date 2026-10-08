import SwiftUI

@Observable
@MainActor
class EditLoadableBarPresenter {
    
    private let interactor: EditLoadableBarInteractor
    private let router: EditLoadableBarRouter
    
    private let loadableBarBinding: Binding<LoadableBars>
    var loadableBar: LoadableBars {
        didSet {
            loadableBarBinding.wrappedValue = loadableBar
        }
    }
    var selectedUnit: ExerciseWeightUnit
    
    init(interactor: EditLoadableBarInteractor, router: EditLoadableBarRouter, loadableBarBinding: Binding<LoadableBars>) {
        self.interactor = interactor
        self.router = router
        self.loadableBarBinding = loadableBarBinding
        self.loadableBar = loadableBarBinding.wrappedValue
        self.selectedUnit = loadableBarBinding.wrappedValue.defaultBaseWeight?.unit ?? .kilograms
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// One collar's weight in the unit being viewed, empty for none. Stored in kilograms, so a
    /// figure typed on the pounds tab reads back the same there.
    var collarWeight: Double? {
        get {
            guard loadableBar.collarWeight > 0 else { return nil }
            let shown = UnitConversion.convertWeight(loadableBar.collarWeight, from: .kilograms, into: selectedUnit)
            return (shown * 1000).rounded() / 1000
        }
        set {
            loadableBar.collarWeight = max(UnitConversion.convertWeightToKg(newValue ?? 0, from: selectedUnit), 0)
        }
    }

    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        loadableBar.baseWeights
            .filter { $0.unit == unit }
            .map { $0.id }
    }

    func weightValue(for id: String) -> Double {
        loadableBar.baseWeights.first(where: { $0.id == id })?.baseWeight ?? 0
    }

    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<LoadableBarsBaseWeight> {
        Binding(
            get: {
                guard let index = self.loadableBar.baseWeights.firstIndex(where: { $0.id == id }) else {
                    return LoadableBarsBaseWeight(
                        id: id,
                        baseWeight: 0,
                        unit: fallbackUnit,
                        isActive: false
                    )
                }
                return self.loadableBar.baseWeights[index]
            },
            set: { updated in
                guard let index = self.loadableBar.baseWeights.firstIndex(where: { $0.id == id }) else {
                    return
                }
                var nextLoadableBar = self.loadableBar
                nextLoadableBar.baseWeights[index] = updated
                self.loadableBar = nextLoadableBar
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let idsToDelete = offsets.compactMap { offset in
            weightIDs.indices.contains(offset) ? weightIDs[offset] : nil
        }
        guard !idsToDelete.isEmpty else { return }

        var updated = loadableBar
        updated.baseWeights.removeAll { idsToDelete.contains($0.id) }
        loadableBar = updated
    }
    
    func onAddPressed() {
        let loadableBarBinding = Binding(
            get: { self.loadableBar },
            set: { self.loadableBar = $0 }
        )
        router.showAddLoadableBarView(delegate: AddLoadableBarDelegate(loadableBar: loadableBarBinding, unit: selectedUnit))
    }
}

extension EditLoadableBarPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditLoadableBarView_Appear"
            case .onDisappear: return "EditLoadableBarView_Disappear"
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
