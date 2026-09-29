import SwiftUI

struct LoggerBannerDelegate { }

struct LoggerBannerView: View {

    @State var presenter: LoggerBannerPresenter
    let delegate: LoggerBannerDelegate

    var body: some View {
        List {
            Section {
                CustomToggleView(
                    title: String(localized: "Calories Ring"),
                    subtitle: String(localized: "Show calorie ring in the logger banner"),
                    bool: $presenter.showCaloriesRing
                )
                CustomToggleView(
                    title: String(localized: "Protein Ring"),
                    subtitle: String(localized: "Show protein ring in the logger banner"),
                    bool: $presenter.showProteinRing
                )
                CustomToggleView(
                    title: String(localized: "Fat Ring"),
                    subtitle: String(localized: "Show fat ring in the logger banner"),
                    bool: $presenter.showFatRing
                )
                CustomToggleView(
                    title: String(localized: "Carbs Ring"),
                    subtitle: String(localized: "Show carbs ring in the logger banner"),
                    bool: $presenter.showCarbsRing
                )
            }
        }
        .navigationTitle("Logger Banner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {

    func loggerBannerView(router: AnyRouter, delegate: LoggerBannerDelegate) -> some View {
        LoggerBannerView(
            presenter: LoggerBannerPresenter(
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
    let delegate = LoggerBannerDelegate()

    return RouterView { router in
        builder.loggerBannerView(router: router, delegate: delegate)
    }
}
