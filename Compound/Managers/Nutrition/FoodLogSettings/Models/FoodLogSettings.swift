import Foundation

enum TimestampSide: String, Codable { case left, right }

struct FoodLogSettings: DataSyncModelProtocol {
    var id: String = "food_log_settings"
    var authorId: String

    // MARK: - Nutrient Reporting
    var showOverages: Bool = false

    // MARK: - Timeline Options
    var showsFoodTimestamps: Bool = true
    var showHourlyMacroTotals: Bool = true
    var showCalendarWeekBanner: Bool = true
    var premove: Bool = false
    var timestampSide: TimestampSide = .left
    var showAddFoodsButton: Bool = true
    var startHour: Int = 7
    var endHour: Int = 23
    /// Collapses each row to its name, hiding the calorie and macro detail beneath it.
    var hideFoodDetails: Bool = false
    /// Drops hours with nothing logged from the timeline instead of showing them empty.
    var hideEmptyHours: Bool = false

    // MARK: - Food Search
    var showBrandedFoods: Bool = true
    var showOpenFoodFactsFoods: Bool = true

    // MARK: - Timeline Food Tiles
    var showFoodImageInTimeline: Bool = true
    var showCaloriesInTimeline: Bool = true
    var showMacrosInTimeline: Bool = true

    // MARK: - Logger Food Tiles
    var showFoodImageInLogger: Bool = true
    var showCaloriesInLogger: Bool = true
    var showMacrosInLogger: Bool = true
    var showPortionInLogger: Bool = true

    // MARK: - Logger Banner
    var showCaloriesRing: Bool = true
    var showProteinRing: Bool = true
    var showFatRing: Bool = true
    var showCarbsRing: Bool = true

    // MARK: - Time Selection
    var autoSetCurrentTime: Bool = false

    // MARK: - Favourite Measurements
    var favouriteMeasurements: [String] = ["g", "oz", "ml", "cup", "serving"]

    // MARK: - Favourites
    /// Per-user favourites, as ids. `FoodModel.favouriteCount` is a community tally and says
    /// nothing about whether *this* user favourited something.
    var favouriteFoodIds: [String] = []
    var favouriteRecipeIds: [String] = []

    // MARK: - Optimisation
    var quickAddEnabled: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case showOverages = "show_overages"
        case showsFoodTimestamps = "shows_food_timestamps"
        case showHourlyMacroTotals = "show_hourly_macro_totals"
        case showCalendarWeekBanner = "show_calendar_week_banner"
        case premove
        case timestampSide = "timestamp_side"
        case showAddFoodsButton = "show_add_foods_button"
        case startHour = "start_hour"
        case endHour = "end_hour"
        case hideFoodDetails = "hide_food_details"
        case hideEmptyHours = "hide_empty_hours"
        case showBrandedFoods = "show_branded_foods"
        case showOpenFoodFactsFoods = "show_open_food_facts_foods"
        case showFoodImageInTimeline = "show_food_image_in_timeline"
        case showCaloriesInTimeline = "show_calories_in_timeline"
        case showMacrosInTimeline = "show_macros_in_timeline"
        case showFoodImageInLogger = "show_food_image_in_logger"
        case showCaloriesInLogger = "show_calories_in_logger"
        case showMacrosInLogger = "show_macros_in_logger"
        case showPortionInLogger = "show_portion_in_logger"
        case showCaloriesRing = "show_calories_ring"
        case showProteinRing = "show_protein_ring"
        case showFatRing = "show_fat_ring"
        case showCarbsRing = "show_carbs_ring"
        case autoSetCurrentTime = "auto_set_current_time"
        case favouriteMeasurements = "favourite_measurements"
        case favouriteFoodIds = "favourite_food_ids"
        case favouriteRecipeIds = "favourite_recipe_ids"
        case quickAddEnabled = "quick_add_enabled"
    }

    var eventParameters: [String: Any] { [:] }
    
    static var mock: FoodLogSettings {
        FoodLogSettings(authorId: "mock_user_123")
    }
}
