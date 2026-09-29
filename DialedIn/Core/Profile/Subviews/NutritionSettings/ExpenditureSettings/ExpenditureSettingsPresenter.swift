import SwiftUI

@Observable
@MainActor
class ExpenditureSettingsPresenter {
    
    private let interactor: ExpenditureSettingsInteractor
    private let router: ExpenditureSettingsRouter
    
    private var settings: NutritionStrategySettings
    private var estimate: ExpenditureEstimate

    /// Presents the calculation start date picker.
    var isChoosingStartDate: Bool = false

    init(interactor: ExpenditureSettingsInteractor, router: ExpenditureSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.nutritionStrategySettings
        self.estimate = interactor.currentExpenditure
    }

    // MARK: - Today's estimate

    var expenditureValueText: String {
        String(localized: "\(String(describing: Int(estimate.kcal.rounded()))) kcal")
    }

    /// One line saying where the figure above came from, because "2,480 kcal" on its own cannot
    /// tell a month of logging apart from a guess off the user's height.
    var expenditureStatusText: String {
        switch estimate.source {
        case .fixed:
            return String(localized: "Fixed")
        case .prior:
            return String(localized: "Estimated from your profile until \(ExpenditureEngine.Constants.minWindowDays) days are logged")
        case .adaptive:
            return String(localized: "Adaptive \u{00B7} \(String(describing: estimate.loggedDays)) of \(String(describing: estimate.windowDays)) days logged")
        }
    }

    /// The step nowcast, when one applied, shown separately so the adjustment is never mistaken
    /// for the measurement.
    var stepAdjustmentText: String? {
        let adjustment = estimate.stepAdjustmentKcal.rounded()
        guard adjustment != 0 else { return nil }
        let sign = adjustment > 0 ? "+" : "\u{2212}"
        return String(localized: "Includes \(sign)\(String(describing: Int(abs(adjustment)))) kcal from your recent step count")
    }

    let estimationMethods = ExpenditureEstimationMethod.allCases
    let bmrEquations = BMREquation.allCases
    let calculationModes = ExpenditureCalculationMode.allCases
    let algorithmVersions = ExpenditureAlgorithmVersion.allCases

    var stepInformedUpdates: Bool {
        get { settings.stepInformedUpdates }
        set { settings.stepInformedUpdates = newValue; save() }
    }

    var predictiveGoalAdjustments: Bool {
        get { settings.predictiveGoalAdjustments }
        set { settings.predictiveGoalAdjustments = newValue; save() }
    }

    var estimationMethod: ExpenditureEstimationMethod {
        get { settings.estimationMethod }
        set { settings.estimationMethod = newValue; save() }
    }

    var bmrEquation: BMREquation {
        get { settings.bmrEquation }
        set { settings.bmrEquation = newValue; save() }
    }

    var calculationMode: ExpenditureCalculationMode {
        get { settings.calculationMode }
        set { settings.calculationMode = newValue; save() }
    }

    var algorithmVersion: ExpenditureAlgorithmVersion {
        get { settings.algorithmVersion }
        set { settings.algorithmVersion = newValue; save() }
    }

    /// Unset means "since you started logging", which is how the estimate already behaves.
    var calculationStartDate: Date {
        get { settings.calculationStartDate ?? Date() }
        set { settings.calculationStartDate = newValue; save() }
    }

    var calculationStartDateLabel: String {
        guard let date = settings.calculationStartDate else { return "Default" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    func onEditStartDatePressed() {
        isChoosingStartDate = true
    }

    func onClearStartDatePressed() {
        settings.calculationStartDate = nil
        isChoosingStartDate = false
        save()
    }

    /// Saving changes the estimate — the mode and the modifiers all feed the engine — so the
    /// figure on screen is re-read rather than left showing what the old settings produced.
    private func save() {
        Task {
            do {
                try await interactor.saveNutritionStrategySettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
            estimate = interactor.currentExpenditure
        }
    }
    
    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `NutritionStrategySettings` document, which the Strategy screen edits too, so a stale copy
    /// would revert whatever was saved over there.
    func onViewAppear() {
        settings = interactor.nutritionStrategySettings
        estimate = interactor.currentExpenditure
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
}

extension ExpenditureSettingsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveFail(error: Error)
        
        var eventName: String {
            switch self {
            case .saveFail: return "ExpenditureSettingsView_Save_Fail"
            case .onAppear: return "ExpenditureSettingsView_Appear"
            case .onDisappear: return "ExpenditureSettingsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default:
                return .analytic
            }
        }
    }
}
