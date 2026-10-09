import SwiftUI

/// What the Add Machine form hands back: the gym builds the machine from it.
struct GymMachineDraft: Equatable {
    var kind: EquipmentKind
    var name: String
    /// A catalogue machine of `kind` this one stands in for in exercises, or nil for a machine
    /// of its own.
    var worksAs: String?
}

@Observable
@MainActor
class AddGymMachinePresenter {

    private let interactor: AddGymMachineInteractor
    private let router: AddGymMachineRouter
    private let delegate: AddGymMachineDelegate

    static let kinds: [EquipmentKind] = [.cableMachine, .pinLoadedMachine, .plateLoadedMachine]

    var kind: EquipmentKind = .cableMachine {
        didSet {
            // The previous choice belongs to another kind's catalogue.
            if kind != oldValue { worksAs = nil }
        }
    }
    var name: String = ""
    var worksAs: String?

    init(interactor: AddGymMachineInteractor, router: AddGymMachineRouter, delegate: AddGymMachineDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }

    /// The catalogue machines of the chosen kind, by name.
    var catalogueMachines: [AnyEquipment] {
        let items: [AnyEquipment]
        switch kind {
        case .cableMachine: items = CableMachine.catalogue.map(AnyEquipment.init)
        case .pinLoadedMachine: items = PinLoadedMachine.catalogue.map(AnyEquipment.init)
        default: items = PlateLoadedMachine.catalogue.map(AnyEquipment.init)
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedName.isEmpty }

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
        guard canSave else { return }
        delegate.onAdd(GymMachineDraft(kind: kind, name: trimmedName, worksAs: worksAs))
        interactor.playHaptic(option: .success)
        router.dismissScreen()
    }
}

extension EquipmentKind {
    /// The short name the Add Machine form's kind picker shows.
    var machineKindTitle: String {
        switch self {
        case .cableMachine: return String(localized: "Cable")
        case .pinLoadedMachine: return String(localized: "Pin-loaded")
        default: return String(localized: "Plate-loaded")
        }
    }
}

extension AddGymMachinePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "AddGymMachineView_Appear"
            case .onDisappear: return "AddGymMachineView_Disappear"
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
