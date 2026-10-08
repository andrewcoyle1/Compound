import SwiftUI

@Observable
@MainActor
class EditWeightRangePresenter {

    private let interactor: EditWeightRangeInteractor
    private let router: EditWeightRangeRouter

    private let rangeBinding: Binding<WeightStack>
    let equipmentName: String

    /// Edited here and written through to the machine. The sheet reads this copy rather than the
    /// binding, because a binding handed to a routed sheet keeps answering with its opening value,
    /// and a list of add-ons would never show the one just added.
    var stack: WeightStack {
        didSet {
            rangeBinding.wrappedValue = stack
        }
    }

    /// The increment the screen opened on, so an unusable one can be put back rather than replaced
    /// with a guess.
    private let openingIncrement: Double

    /// The add-on and pin weight being typed, before Add puts them on the stack.
    var newAddOn: Double?
    var newPinWeight: Double?

    init(interactor: EditWeightRangeInteractor, router: EditWeightRangeRouter, delegate: EditWeightRangeDelegate) {
        self.interactor = interactor
        self.router = router
        self.rangeBinding = delegate.range
        self.equipmentName = delegate.equipmentName
        self.stack = delegate.range.wrappedValue
        self.openingIncrement = delegate.range.wrappedValue.increment
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        repairRange()
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onDismissPressed() {
        repairRange()
        router.dismissScreen()
    }

    // MARK: - Add-ons

    /// Why the add-on being typed cannot be added; nil when it can, or when nothing is typed.
    var addOnMessage: String? {
        guard let value = newAddOn else { return nil }
        guard value > 0 else { return String(localized: "An add-on must weigh more than zero.") }
        guard stack.addOns.count < WeightStack.maxAddOns else {
            return String(localized: "A stack can have up to \(WeightStack.maxAddOns) add-ons.")
        }
        return nil
    }

    var canAddAddOn: Bool { newAddOn != nil && addOnMessage == nil }

    /// Two equal add-ons are allowed: a pair of 2 kg toggles, or a lever with three positions.
    func onAddAddOnPressed() {
        guard canAddAddOn, let value = newAddOn else { return }
        stack.addOns.append(value)
        newAddOn = nil
        interactor.playHaptic(option: .success)
    }

    func onDeleteAddOns(at offsets: IndexSet) {
        stack.addOns.remove(atOffsets: offsets)
    }

    // MARK: - Uneven stack

    /// An uneven stack lists its pin weights instead of the lightest, heaviest and step.
    var isUneven: Bool {
        get { stack.weights != nil }
        set { stack.weights = newValue ? (stack.weights ?? []) : nil }
    }

    /// Why the pin weight being typed cannot be added; nil when it can, or when nothing is typed.
    var pinWeightMessage: String? {
        guard let value = newPinWeight else { return nil }
        guard value > 0 else { return String(localized: "A pin weight must be more than zero.") }
        guard !(stack.weights ?? []).contains(where: { abs($0 - value) < WeightStep.epsilon }) else {
            return String(localized: "This weight is already on the stack.")
        }
        return nil
    }

    var canAddPinWeight: Bool { newPinWeight != nil && pinWeightMessage == nil }

    func onAddPinWeightPressed() {
        guard canAddPinWeight, let value = newPinWeight else { return }
        stack.weights = ((stack.weights ?? []) + [value]).sorted()
        newPinWeight = nil
        interactor.playHaptic(option: .success)
    }

    func onDeletePinWeights(at offsets: IndexSet) {
        stack.weights?.remove(atOffsets: offsets)
    }

    // MARK: - Repair

    /// Puts a stack back into a state weights can actually be picked from.
    ///
    /// Every field here is free text, so a stack can be left with its heaviest pin below its
    /// lightest, or with no increment at all — most easily by clearing the field, which reads as
    /// zero. Both break the rounding that decides what load a machine can be set to: a zero
    /// increment divides by zero and every suggested weight comes back as not-a-number, and an end
    /// below the start clamps every weight to the start, so a whole gym's cable stack reads as its
    /// lightest plate. An uneven stack left with no weights goes back to its grid.
    ///
    /// The add-a-stack screen refuses these outright, but editing one has no such guard, so the
    /// repair happens as the screen is left rather than while the user is still typing.
    private func repairRange() {
        var value = stack

        if value.maxWeight < value.minWeight {
            (value.minWeight, value.maxWeight) = (value.maxWeight, value.minWeight)
        }
        if value.increment <= 0 {
            value.increment = openingIncrement > 0 ? openingIncrement : Self.fallbackIncrement(for: value.unit)
        }
        if value.weights?.isEmpty == true {
            value.weights = nil
        }

        if value != stack {
            stack = value
        }
    }

    /// Used only when the range arrived with an unusable increment too, so there is nothing to
    /// restore: the smallest step the equipment lists are usually built in.
    private static func fallbackIncrement(for unit: ExerciseWeightUnit) -> Double {
        switch unit {
        case .kilograms:    return 2.5
        case .pounds:       return 5
        }
    }
}

extension EditWeightRangePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "EditWeightRangeView_Appear"
            case .onDisappear: return "EditWeightRangeView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            nil
        }

        var type: LogType {
            .analytic
        }
    }
}
