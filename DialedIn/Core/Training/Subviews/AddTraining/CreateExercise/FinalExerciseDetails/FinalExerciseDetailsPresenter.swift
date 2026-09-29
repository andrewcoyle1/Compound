import SwiftUI

@Observable
@MainActor
class FinalExerciseDetailsPresenter {
    
    private let interactor: FinalExerciseDetailsInteractor
    private let router: FinalExerciseDetailsRouter

    var rangeOfMotion: Int = 0
    var stability: Int = 0
    var bodyweightContribution: Int = 75
    var alternateNames: String = ""
    var exerciseDescription: String = ""

    static let contributionRange = 0...100

    init(interactor: FinalExerciseDetailsInteractor, router: FinalExerciseDetailsRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// The field was labelled "Required" but accepted any integer, negative or over 100.
    func canContinue(delegate: FinalExerciseDetailsDelegate) -> Bool {
        !delegate.isBodyweight || Self.contributionRange.contains(bodyweightContribution)
    }

    /// The footer read "XX kg at your current weight." verbatim.
    func contributionFooter(delegate: FinalExerciseDetailsDelegate) -> String {
        guard let kilograms = interactor.currentUser?.submittedWeightKilograms else {
            return String(localized: "The share of your body weight this exercise moves.")
        }
        let unit = interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
        let moved = kilograms * Double(bodyweightContribution) / 100
        let shown = unit == .pounds ? moved * 2.2046226218 : moved
        return String(localized: "About \(String(describing: Int(shown.rounded()))) \(unit.abbreviation) at your current weight.")
    }

    func onNextPressed(delegate: FinalExerciseDetailsDelegate) {
        guard canContinue(delegate: delegate) else { return }
        let alternateNamesArray: [String] = self.alternateNames
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        router.showExerciseSaveView(
            delegate: ExerciseSaveDelegate(
                exerciseName: delegate.name,
                trackableMetricA: delegate.trackableMetricA,
                trackableMetricB: delegate.trackableMetricB,
                type: delegate.exerciseType,
                laterality: delegate.laterality,
                targetMuscles: delegate.targetMuscles,
                isBodyweight: delegate.isBodyweight,
                equipmentVariations: delegate.equipmentVariations,
                rangeOfMotion: self.rangeOfMotion,
                stability: self.stability,
                bodyweightContribution: delegate.isBodyweight ? self.bodyweightContribution : 0,
                alternativeNames: alternateNamesArray,
                exerciseDescription: self.exerciseDescription
            )
        )
    }

    func onViewAppear(delegate: FinalExerciseDetailsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: FinalExerciseDetailsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension FinalExerciseDetailsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: FinalExerciseDetailsDelegate)
        case onDisappear(delegate: FinalExerciseDetailsDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "FinalExerciseDetailsView_Appear"
            case .onDisappear:              return "FinalExerciseDetailsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
//            default:
//                return nil
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
