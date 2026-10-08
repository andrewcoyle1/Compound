import SwiftUI

/// The stacks of one cable or pin-loaded machine. One presenter for both kinds: they differ only in
/// which list of the gym profile they sit in.
@Observable
@MainActor
class EditStackMachinePresenter<Machine: StackMachine> {

    private let interactor: EditStackMachineInteractor
    private let router: EditStackMachineRouter

    private let machineBinding: Binding<Machine>
    var machine: Machine {
        didSet {
            machineBinding.wrappedValue = machine
        }
    }
    var selectedUnit: ExerciseWeightUnit

    init(interactor: EditStackMachineInteractor, router: EditStackMachineRouter, machineBinding: Binding<Machine>) {
        self.interactor = interactor
        self.router = router
        self.machineBinding = machineBinding
        self.machine = machineBinding.wrappedValue
        self.selectedUnit = machineBinding.wrappedValue.defaultRange?.unit ?? .kilograms
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// The stacks in `unit`, by name, so the list does not reshuffle as stacks come and go.
    func filteredWeightIDs(for unit: ExerciseWeightUnit) -> [String] {
        machine.ranges
            .filter { $0.unit == unit }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            }
            .map { $0.id }
    }

    /// Rows are sorted but the machine's list is not, so reads and writes follow the id. A row
    /// mid-removal reads as a placeholder in the unit being viewed, and writing to it changes
    /// nothing.
    func bindingForWeight(id: String, fallbackUnit: ExerciseWeightUnit) -> Binding<WeightStack> {
        Binding(
            get: {
                self.machine.ranges.first { $0.id == id } ?? WeightStack(
                    id: id,
                    name: "Custom Range",
                    minWeight: 0,
                    maxWeight: 150,
                    increment: 2.5,
                    unit: fallbackUnit,
                    isActive: false
                )
            },
            set: { updated in
                guard let index = self.machine.ranges.firstIndex(where: { $0.id == id }) else { return }
                self.machine.ranges[index] = updated
            }
        )
    }

    func deleteWeights(at offsets: IndexSet, weightIDs: [String]) {
        let ids = Set(offsets.compactMap { weightIDs.indices.contains($0) ? weightIDs[$0] : nil })
        guard !ids.isEmpty else { return }
        machine.removeStacks(ids: ids)
    }

    func onEditRangePressed(range: Binding<WeightStack>) {
        router.showEditWeightRangeView(delegate: EditWeightRangeDelegate(equipmentName: machine.name, range: range))
    }

    func onAddPressed() {
        router.showAddWeightStackView(
            delegate: AddWeightStackDelegate(
                machineName: machine.name,
                stacks: machine.ranges,
                unit: selectedUnit,
                onAdd: { [weak self] stack in self?.machine.addStack(stack) }
            )
        )
    }
}

extension EditStackMachinePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "EditStackMachineView_Appear"
            case .onDisappear: return "EditStackMachineView_Disappear"
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
