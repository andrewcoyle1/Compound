import SwiftUI

@Observable
@MainActor
class AddPinLoadedMachineRangePresenter {
    
    private let interactor: AddPinLoadedMachineRangeInteractor
    private let router: AddPinLoadedMachineRangeRouter
    
    var pinLoadedMachine: Binding<PinLoadedMachine>
    var range: PinLoadedMachineRange
    let unit: ExerciseWeightUnit
    
    init(interactor: AddPinLoadedMachineRangeInteractor, router: AddPinLoadedMachineRangeRouter, delegate: AddPinLoadedMachineRangeDelegate) {
        self.interactor = interactor
        self.router = router
        self.pinLoadedMachine = delegate.pinLoadedMachine
        self.unit = delegate.unit
        self.range = PinLoadedMachineRange(
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
    
    func onSavePressed() {
        guard range.minWeight < range.maxWeight else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "The range start must be less than the range end."))
            return
        }
        
        guard range.increment > 0 else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "The increment must be greater than zero."))
            return
        }
        
        let normalizedName = range.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pinLoadedMachine.wrappedValue.ranges.contains(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }) == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "A range with this name already exists."))
            return
        }
        
        guard pinLoadedMachine.wrappedValue.ranges.contains(where: {
            $0.minWeight == range.minWeight &&
            $0.maxWeight == range.maxWeight &&
            $0.increment == range.increment &&
            $0.unit == range.unit
        }) == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "This range is already added."))
            return
        }
        
        var updatedMachine = pinLoadedMachine.wrappedValue
        updatedMachine.ranges.append(range)
        if updatedMachine.defaultRangeId == nil {
            updatedMachine.defaultRangeId = range.id
        }
        pinLoadedMachine.wrappedValue = updatedMachine
        router.dismissScreen()
    }
    
}

extension AddPinLoadedMachineRangePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddPinLoadedMachineRangeView_Appear"
            case .onDisappear: return "AddPinLoadedMachineRangeView_Disappear"
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
