//
//  ShortcutSettings.swift
//  DialedIn
//

import Foundation

/// Which quick actions the Search tab's empty state shows, and in what order.
///
/// Backs the Shortcuts screen, which was a `Text("Hello, World!")` under a "Toolbar" header with a
/// Save button whose action was empty. The Add tab's grid was four hardcoded buttons.
struct ShortcutSettings: DataSyncModelProtocol {

    var id: String = "shortcut_settings"
    var authorId: String

    /// Ordered `QuickAction.rawValue`s, or nil for the default set.
    ///
    /// The ordered visible list rather than a hidden set — the opposite of `AnalyticsSettings`,
    /// deliberately. Analytics sections have a fixed layout order, so storing what is hidden lets a
    /// newly added section appear for everyone. Here the order *is* the user's choice, so it has to
    /// be stored, which means an action added in a later release will not appear in a list that has
    /// already been curated. That is the right trade for a list someone arranged on purpose.
    var quickActionIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case quickActionIds = "quick_action_ids"
    }

    var eventParameters: [String: Any] {
        ["shortcut_quick_action_count": quickActions.count]
    }

    /// Unknown ids are dropped, so an action removed in a later release does not leave a gap, and a
    /// build that predates one does not fail to decode.
    var quickActions: [QuickAction] {
        guard let quickActionIds else { return QuickAction.defaultActions }
        return quickActionIds.compactMap { QuickAction(rawValue: $0) }
    }

    mutating func setQuickActions(_ actions: [QuickAction]) {
        quickActionIds = actions.map(\.rawValue)
    }

    static var mock: ShortcutSettings {
        ShortcutSettings(authorId: UserModel.mock.userId)
    }
}

/// Everything the Search tab can offer. Each case maps to a route `SearchRouter` declares, so this
/// list is bounded by what that screen can actually reach.
///
/// `browse_workouts` was dropped: it opened the same library "Start Workout" used to, and Start
/// Workout now starts one. A stored id for it decodes to nothing, see `quickActions`.
enum QuickAction: String, CaseIterable, Identifiable, Codable {
    case startWorkout = "start_workout"
    case logMeal = "log_meal"
    case logWeight = "log_weight"
    case logMeasurement = "log_measurement"
    case addExercise = "add_exercise"
    case newWorkout = "new_workout"
    case newFood = "new_food"
    case newRecipe = "new_recipe"
    case browseExercises = "browse_exercises"
    case browseRecipes = "browse_recipes"

    var id: String { rawValue }

    /// The things a person records rather than builds: what the other tabs leave furthest away.
    static let defaultActions: [QuickAction] = [.startWorkout, .logMeal, .logWeight, .logMeasurement]

    var title: String {
        switch self {
        case .startWorkout:    return String(localized: "Start Workout")
        case .logMeal:         return String(localized: "Log Meal")
        case .logWeight:       return String(localized: "Log Weight")
        case .logMeasurement:  return String(localized: "Log Measurement")
        case .addExercise:     return String(localized: "New Exercise")
        case .newWorkout:      return String(localized: "New Workout")
        case .newFood:         return String(localized: "New Food")
        case .newRecipe:       return String(localized: "New Recipe")
        case .browseExercises: return String(localized: "Exercises")
        case .browseRecipes:   return String(localized: "Recipes")
        }
    }

    var systemImage: String {
        switch self {
        case .startWorkout:    return "play.circle.fill"
        case .logMeal:         return "fork.knife"
        case .logWeight:       return "scalemass"
        case .logMeasurement:  return "ruler"
        case .addExercise:     return "figure.strengthtraining.traditional"
        case .newWorkout:      return "list.bullet.clipboard"
        case .newFood:         return "carrot"
        case .newRecipe:       return "book.closed"
        case .browseExercises: return "dumbbell"
        case .browseRecipes:   return "books.vertical"
        }
    }
}
