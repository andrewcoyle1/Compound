//
//  PlateCalculatorPresenter.swift
//  Compound
//
//  The plate calculator behind the weight keyboard's loading bar: how the set's weight goes on
//  the bar, which bar the gym loads, and which plates it has. Edits a copy of the gym and hands
//  it back on Done, so closing it changes nothing.
//

import SwiftUI

struct PlateCalculatorDelegate {
    let gym: GymProfileModel
    /// The bar or plate-loaded machine the exercise is loaded on.
    let equipment: EquipmentRef
    let unit: ExerciseWeightUnit
    /// The set's weight in `unit`, or nil when none is entered yet.
    let total: Double?
    let onSave: @MainActor (GymProfileModel) -> Void
}

/// One bar the gym could load, for the bar picker.
struct BarChoice: Identifiable, Equatable {
    let id: String
    let title: String
}

@Observable
@MainActor
final class PlateCalculatorPresenter {

    private let interactor: PlateCalculatorInteractor
    private let router: PlateCalculatorRouter
    private let delegate: PlateCalculatorDelegate

    private(set) var gym: GymProfileModel

    init(interactor: PlateCalculatorInteractor, router: PlateCalculatorRouter, delegate: PlateCalculatorDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.gym = delegate.gym
    }

    var unit: ExerciseWeightUnit { delegate.unit }

    /// "70 kg", the set's weight, under the title.
    var subtitle: String? {
        delegate.total.map { "\(WeightStepper.format($0)) \(unit.abbreviation)" }
    }

    /// What the keyboard steps on with the gym as edited so far.
    var step: WeightStep {
        WeightStepper.steps(for: [delegate.equipment], profile: gym, unit: unit)
    }

    var result: PlateCalculator.Result? {
        let step = step
        guard step.isPlateLoaded, let base = step.baseWeight, let total = delegate.total else { return nil }
        return PlateCalculator.load(total: total, bar: base, plates: step.plates, sleeves: step.sleeves)
    }

    /// The loading for the set's weight, or the bare bar when there is none to load.
    var loading: PlateLoading? {
        let step = step
        guard let base = step.baseWeight else { return nil }
        switch result {
        case .loadable(let perSide)?:
            return PlateLoading(perSide: perSide, base: base, sleeves: step.sleeves, unit: unit)
        case .notLoadable?:
            return nil
        case nil:
            return PlateLoading(perSide: [], base: base, sleeves: step.sleeves, unit: unit)
        }
    }

    // MARK: - Bar

    /// The bars the gym has switched on for this exercise, lightest first. Empty on a
    /// plate-loaded machine, whose base is fixed.
    var barChoices: [BarChoice] {
        guard delegate.equipment.kind == .loadableBar, let bar = gym.loadedBar(typeId: delegate.equipment.equipmentId) else { return [] }
        return bar.baseWeights
            .filter(\.isActive)
            .sorted { $0.kilograms < $1.kilograms }
            .map { BarChoice(id: $0.id, title: "\(WeightStepper.format($0.baseWeight)) \($0.unit.abbreviation)") }
    }

    var chosenBarId: String? {
        gym.loadedBar(typeId: delegate.equipment.equipmentId)?.loadedBaseWeight?.id
    }

    func onBarChosen(_ id: String) {
        gym.chooseBarWeight(id, typeId: delegate.equipment.equipmentId)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.barChosen)
    }

    // MARK: - Plates

    var plateChoices: [PlateChoice] { gym.plateChoices(unit: unit) }

    func onPlateToggled(_ choice: PlateChoice) {
        gym.setPlate(choice.weight, unit: unit, isOn: !choice.isOn)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.plateToggled)
    }

    /// "Not loadable: 67.5 or 72.5 kg" for a weight these plates cannot make on this bar.
    var notLoadableText: String? {
        guard case let .notLoadable(below, above)? = result else { return nil }
        let options = [below, above].compactMap { $0 }.map { WeightStepper.format($0) }
        guard !options.isEmpty else { return String(localized: "Not loadable with these plates") }
        return String(localized: "Not loadable: \(options.formatted(.list(type: .or))) \(unit.abbreviation)")
    }

    // MARK: - Lifecycle

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onDonePressed() {
        delegate.onSave(gym)
        interactor.trackEvent(event: Event.done)
        router.dismissScreen()
    }

    func onClosePressed() {
        router.dismissScreen()
    }
}

extension PlateCalculatorPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case barChosen
        case plateToggled
        case done

        var eventName: String {
            switch self {
            case .onAppear: return "PlateCalculatorView_Appear"
            case .barChosen: return "PlateCalculatorView_Bar_Chosen"
            case .plateToggled: return "PlateCalculatorView_Plate_Toggled"
            case .done: return "PlateCalculatorView_Done"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
