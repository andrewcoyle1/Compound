import SwiftUI

@Observable
@MainActor
class AddWeightStackPresenter {

    private let interactor: AddWeightStackInteractor
    private let router: AddWeightStackRouter

    let delegate: AddWeightStackDelegate
    var range: WeightStack

    init(interactor: AddWeightStackInteractor, router: AddWeightStackRouter, delegate: AddWeightStackDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.range = WeightStack(
            id: UUID().uuidString,
            name: "",
            minWeight: delegate.unit == .pounds ? 5 : 2.5,
            maxWeight: 150,
            increment: delegate.unit == .pounds ? 5 : 2.5,
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
            return String(localized: "The lightest pin must be less than the heaviest.")
        }
        guard range.increment > 0 else {
            return String(localized: "The increment must be greater than zero.")
        }
        let normalizedName = range.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard delegate.stacks.contains(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }) == false else {
            return String(localized: "A range with this name already exists.")
        }
        guard delegate.stacks.contains(where: {
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
        delegate.onAdd(range)
        interactor.playHaptic(option: .success)
        router.dismissScreen()
    }
}

extension AddWeightStackPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "AddWeightStackView_Appear"
            case .onDisappear: return "AddWeightStackView_Disappear"
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
