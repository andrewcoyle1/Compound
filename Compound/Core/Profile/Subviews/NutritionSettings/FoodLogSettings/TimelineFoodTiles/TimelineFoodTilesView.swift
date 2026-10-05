import SwiftUI

struct TimelineFoodTilesDelegate { }

struct TimelineFoodTilesView: View {

    @State var presenter: TimelineFoodTilesPresenter
    let delegate: TimelineFoodTilesDelegate

    var body: some View {
        List {
            Section {
                ListRowToggle(
                    title: String(localized: "Show Food Image"),
                    subtitle: String(localized: "Display food image in timeline rows"),
                    isOn: $presenter.showFoodImageInTimeline
                )
                ListRowToggle(
                    title: String(localized: "Show Calories"),
                    subtitle: String(localized: "Display calorie count in timeline rows"),
                    isOn: $presenter.showCaloriesInTimeline
                )
                ListRowToggle(
                    title: String(localized: "Show Macros"),
                    subtitle: String(localized: "Display P/F/C macros in timeline rows"),
                    isOn: $presenter.showMacrosInTimeline
                )
            }
        }
        .navigationTitle("Timeline Food Tiles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
}

extension CoreBuilder {

    func timelineFoodTilesView(router: AnyRouter, delegate: TimelineFoodTilesDelegate) -> some View {
        TimelineFoodTilesView(
            presenter: TimelineFoodTilesPresenter(
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
    let delegate = TimelineFoodTilesDelegate()

    return RouterView { router in
        builder.timelineFoodTilesView(router: router, delegate: delegate)
    }
}
