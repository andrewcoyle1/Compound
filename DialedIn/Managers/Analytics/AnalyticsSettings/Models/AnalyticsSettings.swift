//
//  AnalyticsSettings.swift
//  DialedIn
//

import Foundation

/// Which sections the Analytics tab shows.
///
/// Backs the Customise Analytics screen, which was a `Text("Hello, World!")` reachable from two
/// places. Analytics had no settings document of its own — the existing three are training,
/// exercise and food-log scoped — so this is a fourth rather than a field bolted onto one of them.
struct AnalyticsSettings: DataSyncModelProtocol {

    var id: String = "analytics_settings"
    var authorId: String

    /// Hidden sections by `AnalyticsSection.rawValue`.
    ///
    /// Stored as the hidden set rather than the visible one so that a section added in a later
    /// release shows up by default instead of being invisible to everyone who saved before it
    /// existed.
    var hiddenSectionIds: [String] = []

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case hiddenSectionIds = "hidden_section_ids"
    }

    var eventParameters: [String: Any] {
        ["analytics_hidden_section_count": hiddenSectionIds.count]
    }

    func isVisible(_ section: AnalyticsSection) -> Bool {
        !hiddenSectionIds.contains(section.rawValue)
    }

    mutating func setVisible(_ isVisible: Bool, for section: AnalyticsSection) {
        if isVisible {
            hiddenSectionIds.removeAll { $0 == section.rawValue }
        } else if !hiddenSectionIds.contains(section.rawValue) {
            hiddenSectionIds.append(section.rawValue)
        }
    }

    static var mock: AnalyticsSettings {
        AnalyticsSettings(authorId: UserModel.mock.userId)
    }
}

/// The Analytics tab's optional sections, in the order the screen lays them out.
///
/// The header cards and the "More" section are deliberately absent: the header is the screen's
/// summary and More is how you reach everything else, so hiding either leaves the tab unusable.
enum AnalyticsSection: String, CaseIterable, Identifiable, Codable {
    case insightsAndAnalytics = "insights_and_analytics"
    case habits
    case nutrition
    case bodyMetrics = "body_metrics"
    case muscleGroups = "muscle_groups"
    case exercises

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insightsAndAnalytics: return String(localized: "Insights & Analytics")
        case .habits:               return String(localized: "Habits")
        case .nutrition:            return String(localized: "Nutrition")
        case .bodyMetrics:          return String(localized: "Body Metrics")
        case .muscleGroups:         return String(localized: "Muscle Groups")
        case .exercises:            return String(localized: "Exercises")
        }
    }

    var systemImage: String {
        switch self {
        case .insightsAndAnalytics: return "chart.line.uptrend.xyaxis"
        case .habits:               return "repeat"
        case .nutrition:            return "fork.knife"
        case .bodyMetrics:          return "figure"
        case .muscleGroups:         return "figure.arms.open"
        case .exercises:            return "dumbbell"
        }
    }
}
