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
                ListRowButton(
                    title: String(localized: "Hour Range"),
                    subtitle: presenter.hourRangeSubtitle,
                    systemImage: Symbol.duration
                ) {
                    presenter.onEditHourRangePressed()
                }
                ListRowButton(
                    title: String(localized: "Alignment"),
                    subtitle: presenter.alignmentSubtitle,
                    systemImage: "chart.bar.yaxis"
                ) {
                    presenter.onEditAlignmentPressed()
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
                    subtitle: String(localized: "Show"),
                    systemImage: Symbol.duration,
                    isOn: $presenter.showHourlyMacroTotals
                )
                ListRowToggle(
                    title: String(localized: "Calendar Week Banner"),
                    subtitle: String(localized: "Show"),
                    systemImage: Symbol.duration,
                    isOn: $presenter.showCalendarWeekBanner
                )
                ListRowToggle(
                    title: String(localized: "Premove"),
                    subtitle: String(localized: "Pre-log meals before eating"),
                    systemImage: Symbol.duration,
                    isOn: $presenter.premove
                )
            } header: {
                Text("Timeline Options")
            }

            Section {
                ListRowToggle(
                    title: String(localized: "Branded Results"),
                    subtitle: presenter.showBrandedFoods ? String(localized: "On") : String(localized: "Off"),
                    isOn: $presenter.showBrandedFoods
                )
                ListRowToggle(
                    title: String(localized: "Open Food Facts Results"),
                    subtitle: presenter.showOpenFoodFactsFoods ? String(localized: "On") : String(localized: "Off"),
                    isOn: $presenter.showOpenFoodFactsFoods
                )
            } header: {
                Text("Food Search")
            }

            Section {
                ListRowButton(
                    title: String(localized: "Timeline Food Tiles"),
                    subtitle: String(localized: "Customise how foods appear in your timeline")
                ) {
                    presenter.onTimelineFoodTilesPressed()
                }
                ListRowButton(
                    title: String(localized: "Logger Food Tiles"),
                    subtitle: String(localized: "Customise how foods appear in search")
                ) {
                    presenter.onLoggerFoodTilesPressed()
                }
            } header: {
                Text("Food Tiles")
            }

            Section {
                ListRowButton(
                    title: String(localized: "Logger Banner"),
                    subtitle: String(localized: "Customise the top of your plate")
                ) {
                    presenter.onLoggedBannerPressed()
                }
                ListRowButton(
                    title: String(localized: "Time Selection"),
                    subtitle: String(localized: "Customise how you change time while logging")
                ) {
                    presenter.onTimeSelectionPressed()
                }
                ListRowButton(
                    title: String(localized: "Favourite Measurements"),
                    subtitle: String(localized: "Select the measurements to pin to serving size selections.")
                ) {
                    presenter.onFavouriteMeasurementsPressed()
                }
                ListRowButton(
                    title: String(localized: "Optimisation"),
                    subtitle: String(localized: "Optimise for speed")
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
        .sheet(isPresented: $presenter.isShowingHourRangePicker) {
            hourRangePickerSheet
        }
    }

    private var hourRangePickerSheet: some View {
        NavigationStack {
            Form {
                Picker("Start Hour", selection: $presenter.startHour) {
                    ForEach(0..<24) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                Picker("End Hour", selection: $presenter.endHour) {
                    ForEach(0..<24) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Hour Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        presenter.isShowingHourRangePicker = false
                    }
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return String(localized: "12 AM")
        case 12: return String(localized: "12 PM")
        case 1..<12: return String(localized: "\(String(describing: hour)) AM")
        default: return String(localized: "\(String(describing: hour - 12)) PM")
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
