import SwiftUI

struct EquipmentVariationDraft: Identifiable {
    var id: String = UUID().uuidString
    var resistanceEquipment: [EquipmentRef] = []
    var supportEquipment: [EquipmentRef] = []
}

@Observable
@MainActor
class ExerciseEquipmentPresenter {

    private let interactor: ExerciseEquipmentInteractor
    private let router: ExerciseEquipmentRouter

    var variations: [EquipmentVariationDraft] = [EquipmentVariationDraft()]
    var bodyweightExercise: Bool = false
    private var equipmentIndex: [EquipmentRef: AnyEquipment] = [:]

    var canContinue: Bool {
        bodyweightExercise || variations.contains { !$0.resistanceEquipment.isEmpty }
    }

    init(interactor: ExerciseEquipmentInteractor, router: ExerciseEquipmentRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        equipmentIndex = Dictionary(
            uniqueKeysWithValues: interactor.allEquipmentTypes.map { ($0.ref, $0) }
        )
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func variationName(for index: Int) -> String {
        String(localized: "Variation \(String(describing: index + 1))")
    }

    func onAddVariationPressed() {
        variations.append(EquipmentVariationDraft())
    }

    func onDeleteVariationPressed(id: String) {
        guard variations.count > 1 else { return }
        variations.removeAll { $0.id == id }
    }

    func onAddResistancePressed(variationId: String) {
        guard let idx = variations.firstIndex(where: { $0.id == variationId }) else { return }

        let chosenBinding = Binding<[EquipmentRef]>(
            get: { self.variations[idx].resistanceEquipment },
            set: { self.variations[idx].resistanceEquipment = $0 }
        )

        let equipmentItems = interactor.allEquipmentTypes.filter {
            $0.ref.kind != .supportEquipment && $0.ref.kind != .accessoryEquipment
        }
        let delegate = EquipmentPickerDelegate(
            items: equipmentItems,
            headerTitle: "Resistance Equipment",
            chosenItem: chosenBinding
        )
        router.showEquipmentPickerView(delegate: delegate)
    }

    func onAddSupportPressed(variationId: String) {
        guard let idx = variations.firstIndex(where: { $0.id == variationId }) else { return }

        let chosenBinding = Binding<[EquipmentRef]>(
            get: { self.variations[idx].supportEquipment },
            set: { self.variations[idx].supportEquipment = $0 }
        )

        let equipmentItems = interactor.allEquipmentTypes.filter {
            $0.ref.kind == .supportEquipment || $0.ref.kind == .accessoryEquipment
        }
        let delegate = EquipmentPickerDelegate(
            items: equipmentItems,
            headerTitle: "Support Equipment",
            chosenItem: chosenBinding
        )
        router.showEquipmentPickerView(delegate: delegate)
    }

    func resistanceSubtitle(for variation: EquipmentVariationDraft) -> String {
        guard !variation.resistanceEquipment.isEmpty else {
            return String(localized: "Equipment that adds load to the exercise")
        }
        return variation.resistanceEquipment.map { name(for: $0) }.joined(separator: ", ")
    }

    func supportSubtitle(for variation: EquipmentVariationDraft) -> String {
        guard !variation.supportEquipment.isEmpty else {
            return String(localized: "Equipment that assists, stabilizes, or makes the movement possible")
        }
        return variation.supportEquipment.map { name(for: $0) }.joined(separator: ", ")
    }

    func onNextPressed(delegate: ExerciseEquipmentDelegate) {
        let finalVariations = variations.map {
            EquipmentVariation(id: $0.id, resistanceEquipment: $0.resistanceEquipment, supportEquipment: $0.supportEquipment)
        }
        router.showFinalExerciseDetailsView(
            delegate: FinalExerciseDetailsDelegate(
                name: delegate.name,
                trackableMetricA: delegate.trackableMetricA,
                trackableMetricB: delegate.trackableMetricB,
                exerciseType: delegate.exerciseType,
                laterality: delegate.laterality,
                targetMuscles: delegate.muscleGroups,
                isBodyweight: bodyweightExercise,
                // The toggle only hid the variations; their drafts were still saved on the exercise.
                equipmentVariations: bodyweightExercise ? [] : finalVariations
            )
        )
    }

    private func name(for ref: EquipmentRef) -> String {
        equipmentIndex[ref]?.name ?? ref.equipmentId
    }
}

extension ExerciseEquipmentPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "ExerciseEquipmentView_Appear"
            case .onDisappear: return "ExerciseEquipmentView_Disappear"
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
