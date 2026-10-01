import SwiftUI

@Observable
@MainActor
class EditWeightRangePresenter {
    
    private let interactor: EditWeightRangeInteractor
    private let router: EditWeightRangeRouter

    /// The increment the screen opened on, so an unusable one can be put back rather than replaced
    /// with a guess.
    private var openingIncrement: Double?
    
    init(interactor: EditWeightRangeInteractor, router: EditWeightRangeRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear<Range: WeightRange>(delegate: EditWeightRangeDelegate<Range>) {
        openingIncrement = delegate.range.wrappedValue.increment
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear<Range: WeightRange>(delegate: EditWeightRangeDelegate<Range>) {
        repairRange(delegate.range)
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onDismissPressed<Range: WeightRange>(delegate: EditWeightRangeDelegate<Range>) {
        repairRange(delegate.range)
        router.dismissScreen()
    }

    /// Puts a range back into a state weights can actually be picked from.
    ///
    /// Every field here is free text, so a range can be left with its end below its start, or with
    /// no increment at all — most easily by clearing the field, which reads as zero. Both break the
    /// rounding that decides what load a machine can be set to: a zero increment divides by zero and
    /// every suggested weight comes back as not-a-number, and an end below the start clamps every
    /// weight to the start, so a whole gym's cable stack reads as its lightest plate.
    ///
    /// The add-a-range screen refuses both outright, but editing one had no such guard, so the
    /// repair happens as the screen is left rather than while the user is still typing.
    private func repairRange<Range: WeightRange>(_ range: Binding<Range>) {
        var value = range.wrappedValue
        var changed = false

        if value.maxWeight < value.minWeight {
            let start = value.minWeight
            value.minWeight = value.maxWeight
            value.maxWeight = start
            changed = true
        }

        if value.increment <= 0 {
            value.increment = openingIncrement.flatMap { $0 > 0 ? $0 : nil } ?? Self.fallbackIncrement(for: value.unit)
            changed = true
        }

        guard changed else { return }
        range.wrappedValue = value
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
