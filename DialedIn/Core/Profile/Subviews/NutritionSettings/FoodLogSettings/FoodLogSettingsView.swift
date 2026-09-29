import SwiftUI

struct FoodLogSettingsDelegate {

}

struct FoodLogSettingsView: View {

    @State var presenter: FoodLogSettingsPresenter
    let delegate: FoodLogSettingsDelegate

    var body: some View {
        List {
            Section {
                CustomToggleView(
                    title: String(localized: "Show Overages"),
                    subtitle: presenter.showOveragesSubtitle,
                    bool: $presenter.showOverages
                )
            } header: {
                Text("Nutrient Reporting")
            }

            Section {
                CustomLabelButtonView(
                    symbolName: "clock",
                    title: String(localized: "Hour Range"),
                    subtitle: presenter.hourRangeSubtitle) {
                        Text("Edit")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.onEditHourRangePressed()
                            }
                    }
                CustomLabelButtonView(
                    symbolName: "chart.bar.yaxis",
                    title: String(localized: "Alignment"),
                    subtitle: presenter.alignmentSubtitle) {
                        Text("Edit")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.onEditAlignmentPressed()
                            }
                    }
                CustomToggleView(
                    symbolName: "plus.circle",
                    title: String(localized: "Add Foods to Hour"),
                    subtitle: String(localized: "Show + button on each hour"),
                    bool: $presenter.showAddFoodsButton
                )
                CustomToggleView(
                    symbolName: "clock",
                    title: String(localized: "Food Timestamps"),
                    subtitle: String(localized: "Show timestamps"),
                    bool: $presenter.showsFoodTimestamps
                )
                CustomToggleView(
                    symbolName: "clock",
                    title: String(localized: "Hourly Macro Totals"),
                    subtitle: String(localized: "Show"),
                    bool: $presenter.showHourlyMacroTotals
                )
                CustomToggleView(
                    symbolName: "clock",
                    title: String(localized: "Calendar Week Banner"),
                    subtitle: String(localized: "Show"),
                    bool: $presenter.showCalendarWeekBanner
                )
                CustomToggleView(
                    symbolName: "clock",
                    title: String(localized: "Premove"),
                    subtitle: String(localized: "Pre-log meals before eating"),
                    bool: $presenter.premove
                )
            } header: {
                Text("Timeline Options")
            }

            Section {
                CustomToggleView(
                    title: String(localized: "Branded Results"),
                    subtitle: presenter.showBrandedFoods ? String(localized: "On") : String(localized: "Off"),
                    bool: $presenter.showBrandedFoods
                )
                CustomToggleView(
                    title: String(localized: "Open Food Facts Results"),
                    subtitle: presenter.showOpenFoodFactsFoods ? String(localized: "On") : String(localized: "Off"),
                    bool: $presenter.showOpenFoodFactsFoods
                )
            } header: {
                Text("Food Search")
            }

            Section {
                CustomLabelButtonView(
                    title: String(localized: "Timeline Food Tiles"),
                    subtitle: String(localized: "Customise how foods appear in your timeline")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onTimelineFoodTilesPressed()
                            }
                        .accessibilityLabel("Timeline Food Tiles")

                    }
                CustomLabelButtonView(
                    title: String(localized: "Logger Food Tiles"),
                    subtitle: String(localized: "Customise how foods appear in search")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onLoggerFoodTilesPressed()
                            }
                        .accessibilityLabel("Logger Food Tiles")

                    }
            } header: {
                Text("Food Tiles")
            }

            Section {
                CustomLabelButtonView(
                    title: String(localized: "Logger Banner"),
                    subtitle: String(localized: "Customise the top of your plate")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onLoggedBannerPressed()
                            }
                        .accessibilityLabel("Logger Banner")

                    }
                CustomLabelButtonView(
                    title: String(localized: "Time Selection"),
                    subtitle: String(localized: "Customise how you change time while logging")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onTimeSelectionPressed()
                            }
                        .accessibilityLabel("Time Selection")

                    }
                CustomLabelButtonView(
                    title: String(localized: "Favourite Measurements"),
                    subtitle: String(localized: "Select the measurements to pin to serving size selections.")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onFavouriteMeasurementsPressed()
                            }
                        .accessibilityLabel("Favourite Measurements")

                    }
                CustomLabelButtonView(
                    title: String(localized: "Optimisation"),
                    subtitle: String(localized: "Optimise for speed")) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding()
                            .anyButton(.press) {
                                presenter.onOptimisationPressed()
                            }
                        .accessibilityLabel("Optimisation")
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
                    Button("Done") {
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
