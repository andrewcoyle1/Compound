//
//  NutritionStrategySettings.swift
//  DialedIn
//

import Foundation

/// Backs both the Strategy and Expenditure settings screens. They were previously mockups whose
/// controls discarded every change.
///
/// The expenditure fields are read by `ExpenditureEngine`: `calculationMode`,
/// `calculationStartDate`, `algorithmVersion` and `stepInformedUpdates` shape the estimate, and
/// `predictiveGoalAdjustments` shapes the `TargetProposal` built on it. `estimationMethod` and
/// `bmrEquation` still shape the prior through `resolvedBMREquation`. The strategy fields above
/// them — the check-in cadence, partial logging, fasting and logging breaks — drive the weekly
/// check-in: `CheckInSchedule` reads `checkInWeekday`, and `CheckInPresenter` builds its step
/// list from the other five. See `docs/specs/adaptive-expenditure.md` and
/// `docs/specs/weekly-check-in.md`.
struct NutritionStrategySettings: DataSyncModelProtocol {

    var id: String = "nutrition_strategy_settings"
    var authorId: String

    // MARK: - Strategy
    var checkInWeekday: Int = 2
    var fastCheckIn: Bool = false
    var partialLoggingEnabled: Bool = true
    var weighInEnabled: Bool = true
    var fastingEnabled: Bool = true
    var loggingBreakEnabled: Bool = true

    // MARK: - Expenditure
    var estimationMethod: ExpenditureEstimationMethod = .standard
    var calculationStartDate: Date?
    var bmrEquation: BMREquation = .mifflinStJeor
    var calculationMode: ExpenditureCalculationMode = .dynamic
    var algorithmVersion: ExpenditureAlgorithmVersion = .version1

    // MARK: - Expenditure Modifiers
    var stepInformedUpdates: Bool = false
    var predictiveGoalAdjustments: Bool = true

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case checkInWeekday = "check_in_weekday"
        case fastCheckIn = "fast_check_in"
        case partialLoggingEnabled = "partial_logging_enabled"
        case weighInEnabled = "weigh_in_enabled"
        case fastingEnabled = "fasting_enabled"
        case loggingBreakEnabled = "logging_break_enabled"
        case estimationMethod = "estimation_method"
        case calculationStartDate = "calculation_start_date"
        case bmrEquation = "bmr_equation"
        case calculationMode = "calculation_mode"
        case algorithmVersion = "algorithm_version"
        case stepInformedUpdates = "step_informed_updates"
        case predictiveGoalAdjustments = "predictive_goal_adjustments"
    }

    var eventParameters: [String: Any] {
        [:]
    }

    static var mock: Self {
        NutritionStrategySettings(authorId: "mock_user_123")
    }

    /// Which BMR equation the expenditure estimate actually runs, given what has been logged.
    ///
    /// `estimationMethod` sits above `bmrEquation` on the same screen and promises to "use your
    /// logged body fat percentage where one is available". Katch-McArdle is the only equation in
    /// the app that reads body fat, so being body-fat aware means running it.
    ///
    /// Without a usable percentage there is nothing to be aware of, and inventing one is worse
    /// than the equation the user picked — so the choice stands. `.standard`, the default, always
    /// leaves it alone, which is what every existing estimate already does.
    func resolvedBMREquation(bodyFatPercentage: Double?) -> BMREquation {
        guard estimationMethod == .bodyFatAware,
              let bodyFat = bodyFatPercentage,
              bodyFat > 0, bodyFat < 100 else { return bmrEquation }
        return .katchMcArdle
    }

    /// Monday-first weekday names, indexed by `Calendar`'s 1-based `weekday`.
    var checkInWeekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard checkInWeekday >= 1, checkInWeekday <= symbols.count else { return "Monday" }
        return symbols[checkInWeekday - 1]
    }
}

enum ExpenditureEstimationMethod: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case standard
    case bodyFatAware

    var title: String {
        switch self {
        case .standard:     return String(localized: "Standard")
        case .bodyFatAware: return String(localized: "Body-fat aware")
        }
    }

    var subtitle: String {
        switch self {
        case .standard:
            return String(localized: "Estimate from height, weight, age and activity.")
        case .bodyFatAware:
            return String(localized: "Use your logged body fat percentage where one is available, which suits leaner or heavier builds better.")
        }
    }
}

enum BMREquation: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case mifflinStJeor
    case harrisBenedict
    case katchMcArdle

    var title: String {
        switch self {
        case .mifflinStJeor:  return String(localized: "Mifflin-St Jeor")
        case .harrisBenedict: return String(localized: "Harris-Benedict")
        case .katchMcArdle:   return String(localized: "Katch-McArdle")
        }
    }

    var subtitle: String {
        switch self {
        case .mifflinStJeor:
            return String(localized: "The usual default, and the most accurate for most people.")
        case .harrisBenedict:
            return String(localized: "Older, and tends to read slightly high.")
        case .katchMcArdle:
            return String(localized: "Based on lean mass, so it needs a body fat percentage to mean anything.")
        }
    }
}

enum ExpenditureCalculationMode: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case dynamic
    case fixed

    var title: String {
        switch self {
        case .dynamic: return String(localized: "Dynamic")
        case .fixed:   return String(localized: "Fixed")
        }
    }

    var subtitle: String {
        switch self {
        case .dynamic:
            return String(localized: "Adapt the estimate as your logged intake and weight change over time.")
        case .fixed:
            return String(localized: "Keep the estimate where it is until you change it yourself.")
        }
    }
}

enum ExpenditureAlgorithmVersion: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case version1 = "v1"

    var title: String {
        switch self {
        case .version1: return String(localized: "Expenditure V1")
        }
    }

    var subtitle: String {
        switch self {
        case .version1: return String(localized: "The only version so far.")
        }
    }
}
