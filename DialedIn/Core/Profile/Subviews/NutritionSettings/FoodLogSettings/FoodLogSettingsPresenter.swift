import SwiftUI

@Observable
@MainActor
class FoodLogSettingsPresenter {

    private let interactor: FoodLogSettingsInteractor
    private let router: FoodLogSettingsRouter

    private var settings: FoodLogSettings

    var isShowingHourRangePicker: Bool = false

    var showOverages: Bool {
        get { settings.showOverages }
        set { settings.showOverages = newValue; save() }
    }

    /// What the Show Overages row says beneath itself.
    ///
    /// Lives here rather than inline in the view because the two halves had been written the
    /// wrong way round — on, the row claimed overages would be hidden — and a subtitle a test can
    /// read is a subtitle that cannot silently invert again.
    var showOveragesSubtitle: String {
        showOverages
            ? "Negative numbers will be used in nutrient remaining views if you exceed your target."
            : "No negative numbers will be used if you exceed a nutrient target."
    }

    var showsFoodTimestamps: Bool {
        get { settings.showsFoodTimestamps }
        set { settings.showsFoodTimestamps = newValue; save() }
    }

    var showHourlyMacroTotals: Bool {
        get { settings.showHourlyMacroTotals }
        set { settings.showHourlyMacroTotals = newValue; save() }
    }

    var showCalendarWeekBanner: Bool {
        get { settings.showCalendarWeekBanner }
        set { settings.showCalendarWeekBanner = newValue; save() }
    }

    var premove: Bool {
        get { settings.premove }
        set { settings.premove = newValue; save() }
    }

    var timestampSide: TimestampSide {
        get { settings.timestampSide }
        set { settings.timestampSide = newValue; save() }
    }

    var showAddFoodsButton: Bool {
        get { settings.showAddFoodsButton }
        set { settings.showAddFoodsButton = newValue; save() }
    }

    var startHour: Int {
        get { settings.startHour }
        set { settings.startHour = newValue; save() }
    }

    var endHour: Int {
        get { settings.endHour }
        set { settings.endHour = newValue; save() }
    }

    var showBrandedFoods: Bool {
        get { settings.showBrandedFoods }
        set { settings.showBrandedFoods = newValue; save() }
    }

    var showOpenFoodFactsFoods: Bool {
        get { settings.showOpenFoodFactsFoods }
        set { settings.showOpenFoodFactsFoods = newValue; save() }
    }

    var hourRangeSubtitle: String {
        "\(hourLabel(startHour)) – \(hourLabel(endHour))"
    }

    var alignmentSubtitle: String {
        timestampSide == .left ? String(localized: "Left") : String(localized: "Right")
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return String(localized: "12 AM")
        case 12: return String(localized: "12 PM")
        case 1..<12: return String(localized: "\(String(describing: hour)) AM")
        default: return String(localized: "\(String(describing: hour - 12)) PM")
        }
    }

    init(interactor: FoodLogSettingsInteractor, router: FoodLogSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.foodLogSettings
    }

    private func save() {
        Task {
            do {
                try await interactor.saveFoodLogSettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onViewAppear() {
        // Six of this screen's rows push a sub-screen that edits the *same* settings document and
        // saves it. Coming back, the snapshot taken when this screen was first pushed is out of
        // date, so the next toggle here would save it and undo whatever was changed in there.
        // Re-reading on every appear — including the pop back from a sub-screen — keeps the two in
        // step. The same is true of the favourite food and recipe ids, which are written from the
        // nutrition tab and live in this document too.
        settings = interactor.foodLogSettings
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onEditHourRangePressed() {
        isShowingHourRangePicker = true
    }

    func onEditAlignmentPressed() {
        router.showAlert(
            title: String(localized: "Timestamp Side"),
            subtitle: nil,
            buttons: {
                AnyView(
                    VStack {
                        Button("Left") { self.timestampSide = .left }
                        Button("Right") { self.timestampSide = .right }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onLoggedBannerPressed() {
        router.showLoggerBannerView(delegate: LoggerBannerDelegate())
    }

    func onTimelineFoodTilesPressed() {
        router.showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate())
    }

    func onLoggerFoodTilesPressed() {
        router.showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate())
    }

    func onTimeSelectionPressed() {
        router.showTimeSelectionView(delegate: TimeSelectionDelegate())
    }

    func onFavouriteMeasurementsPressed() {
        router.showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate())
    }

    func onOptimisationPressed() {
        router.showOptimisationView(delegate: OptimisationDelegate())
    }
}

extension FoodLogSettingsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "FoodLogSettingsView_Save_Fail"
            case .onAppear: return "FoodLogSettingsView_Appear"
            case .onDisappear: return "FoodLogSettingsView_Disappear"
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
