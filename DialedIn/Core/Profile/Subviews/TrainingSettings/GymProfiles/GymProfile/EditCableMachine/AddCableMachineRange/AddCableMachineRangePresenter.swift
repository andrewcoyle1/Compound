import SwiftUI

@Observable
@MainActor
class AddCableMachineRangePresenter {
    
    private let interactor: AddCableMachineRangeInteractor
    private let router: AddCableMachineRangeRouter
    
    var cableMachine: Binding<CableMachine>
    var range: CableMachineRange
    let unit: ExerciseWeightUnit
    
    init(interactor: AddCableMachineRangeInteractor, router: AddCableMachineRangeRouter, delegate: AddCableMachineRangeDelegate) {
        self.interactor = interactor
        self.router = router
        self.cableMachine = delegate.cableMachine
        self.unit = delegate.unit
        self.range = CableMachineRange(
            id: UUID().uuidString,
            name: "",
            minWeight: 0,
            maxWeight: 150,
            increment: 2.5,
            unit: delegate.unit,
            isActive: true
        )
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
    
    /// Why the form cannot be saved yet, shown under the fields; nil when it can. Confirm stays
    /// disabled until then, rather than reporting the problem in an alert after the tap.
    var validationMessage: String? {
        guard range.minWeight < range.maxWeight else {
            return String(localized: "The range start must be less than the range end.")
        }
        guard range.increment > 0 else {
            return String(localized: "The increment must be greater than zero.")
        }
        let normalizedName = range.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cableMachine.wrappedValue.ranges.contains(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }) == false else {
            return String(localized: "A range with this name already exists.")
        }
        guard cableMachine.wrappedValue.ranges.contains(where: {
            $0.minWeight == range.minWeight &&
            $0.maxWeight == range.maxWeight &&
            $0.increment == range.increment &&
            $0.unit == range.unit
        }) == false else {
            return String(localized: "This range is already added.")
        }
        return nil
    }

    func onSavePressed() {
        guard validationMessage == nil else { return }
        
        var updatedMachine = cableMachine.wrappedValue
        updatedMachine.ranges.append(range)
        if updatedMachine.defaultRangeId == nil {
            updatedMachine.defaultRangeId = range.id
        }
        cableMachine.wrappedValue = updatedMachine
        router.dismissScreen()
    }
    
}

extension AddCableMachineRangePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddCableMachineRangeView_Appear"
            case .onDisappear: return "AddCableMachineRangeView_Disappear"
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
