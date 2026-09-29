import SwiftUI

struct FoodLogSettingsDelegate {

}

struct FoodLogSettingsView: View {

    @State var presenter: FoodLogSettingsPresenter
    let delegate: FoodLogSettingsDelegate

    var body: some View {
        List {
            Section {
                ListRowToggle(
                    title: String(localized: "Show Overages"),
                    subtitle: presenter.showOveragesSubtitle,
                    isOn: $presenter.showOverages
                )
            } header: {
                Text("Nutrient Reporting")
            }

            Section {
                // Inline pickers, not a sheet and an alert: each is a short choice.
                hourPicker("Start Hour", selection: $presenter.startHour)
                hourPicker("End Hour", selection: $presenter.endHour)
                Picker("Timestamp Side", selection: $presenter.timestampSide) {
                    Text("Left").tag(TimestampSide.left)
                    Text("Right").tag(TimestampSide.right)
                }
                ListRowToggle(
                    title: String(localized: "Add Foods to Hour"),
                    subtitle: String(localized: "Show + button on each hour"),
                    systemImage: Symbol.add,
                    isOn: $presenter.showAddFoodsButton
                )
                ListRowToggle(
                    title: String(localized: "Food Timestamps"),
                    subtitle: String(localized: "Show timestamps"),
                    systemImage: Symbol.duration,
                    isOn: $presenter.showsFoodTimestamps
                )
                ListRowToggle(
                    title: String(localized: "Hourly Macro Totals"),
                    subtitle: nil,
                    isOn: $presenter.showHourlyMacroTotals
                )
                ListRowToggle(
                    title: String(localized: "Calendar Week Banner"),
                    subtitle: nil,
                    isOn: $presenter.showCalendarWeekBanner
                )
                // swiftlint:disable:next todo
                // TODO: The Premove switch is hidden: `FoodLogSettings.premove` is saved but nothing reads it. Restore a "Premove" `ListRowToggle` bound to `presenter.premove` here once the timeline can pre-log meals.
            } header: {
                Text("Timeline Options")
            }

            Section {
                ListRowToggle(
                    title: String(localized: "Branded Results"),
                    subtitle: nil,
                    isOn: $presenter.showBrandedFoods
                )
                ListRowToggle(
                    title: String(localized: "Open Food Facts Results"),
                    subtitle: nil,
                    isOn: $presenter.showOpenFoodFactsFoods
                )
            } header: {
                Text("Food Search")
            }

            Section {
                ListRowButton(
                    title: String(localized: "Timeline Food Tiles"),
                    subtitle: String(localized: "Customize how foods appear in your timeline")
                ) {
                    presenter.onTimelineFoodTilesPressed()
                }
                ListRowButton(
                    title: String(localized: "Logger Food Tiles"),
                    subtitle: String(localized: "Customize how foods appear in search")
                ) {
                    presenter.onLoggerFoodTilesPressed()
                }
            } header: {
                Text("Food Tiles")
            }

            Section {
                ListRowButton(
                    title: String(localized: "Logger Banner"),
                    subtitle: String(localized: "Customize the top of your plate")
                ) {
                    presenter.onLoggedBannerPressed()
                }
                ListRowButton(
                    title: String(localized: "Time Selection"),
                    subtitle: String(localized: "Customize how you change time while logging")
                ) {
                    presenter.onTimeSelectionPressed()
                }
                ListRowButton(
                    title: String(localized: "Favorite Measurements"),
                    subtitle: String(localized: "Select the measurements to pin to serving size selections.")
                ) {
                    presenter.onFavouriteMeasurementsPressed()
                }
                ListRowButton(
                    title: String(localized: "Optimization"),
                    subtitle: String(localized: "Optimize for speed")
                ) {
                    presenter.onOptimisationPressed()
                }

            } header: {
                Text("Logger Options")
            }
        }
        .navigationTitle("Food Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func hourPicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(FoodLogSettingsPresenter.hourLabel(hour)).tag(hour)
            }
        }
    }
}

extension CoreBuilder {

    func foodLogSettingsView(router: AnyRouter, delegate: FoodLogSettingsDelegate) -> some View {
        FoodLogSettingsView(
            presenter: FoodLogSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.foodLogSettingsView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = FoodLogSettingsDelegate()

    return RouterView { router in
        builder.foodLogSettingsView(router: router, delegate: delegate)
    }

}
