import SwiftUI

@MainActor
protocol FoodLogSettingsRouter: GlobalRouter {
    func showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate)
    func showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate)
    func showLoggerBannerView(delegate: LoggerBannerDelegate)
    func showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate)
}

extension CoreRouter: FoodLogSettingsRouter {

    func showTimelineFoodTilesView(delegate: TimelineFoodTilesDelegate) {
        router.showScreen(.push) { router in
            builder.timelineFoodTilesView(router: router, delegate: delegate)
        }
    }

    func showLoggerFoodTilesView(delegate: LoggerFoodTilesDelegate) {
        router.showScreen(.push) { router in
            builder.loggerFoodTilesView(router: router, delegate: delegate)
        }
    }

    func showLoggerBannerView(delegate: LoggerBannerDelegate) {
        router.showScreen(.push) { router in
            builder.loggerBannerView(router: router, delegate: delegate)
        }
    }

    func showFavouriteMeasurementsView(delegate: FavouriteMeasurementsDelegate) {
        router.showScreen(.push) { router in
            builder.favouriteMeasurementsView(router: router, delegate: delegate)
        }
    }
}
