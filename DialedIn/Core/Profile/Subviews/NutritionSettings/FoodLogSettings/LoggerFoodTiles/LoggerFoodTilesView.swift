import SwiftUI

struct LoggerFoodTilesDelegate { }

struct LoggerFoodTilesView: View {

    @State var presenter: LoggerFoodTilesPresenter
    let delegate: LoggerFoodTilesDelegate

    var body: some View {
        List {
            Section {
                ListRowToggle(
                    title: String(localized: "Show Food Image"),
                    subtitle: String(localized: "Display food image in search result rows"),
                    isOn: $presenter.showFoodImageInLogger
                )
                ListRowToggle(
                    title: String(localized: "Show Calories"),
                    subtitle: String(localized: "Display calorie count in search result rows"),
                    isOn: $presenter.showCaloriesInLogger
                )
                ListRowToggle(
                    title: String(localized: "Show Macros"),
                    subtitle: String(localized: "Display P/F/C macros in search result rows"),
                    isOn: $presenter.showMacrosInLogger
                )
                ListRowToggle(
                    title: String(localized: "Show Portion"),
                    subtitle: String(localized: "Display portion size in search result rows"),
                    isOn: $presenter.showPortionInLogger
                )
            }
        }
        .navigationTitle("Logger Food Tiles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {

    func loggerFoodTilesView(router: AnyRouter, delegate: LoggerFoodTilesDelegate) -> some View {
        LoggerFoodTilesView(
            presenter: LoggerFoodTilesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = LoggerFoodTilesDelegate()

    return RouterView { router in
        builder.loggerFoodTilesView(router: router, delegate: delegate)
    }
}
