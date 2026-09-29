//
//  TabBarView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/5/24.
//

import SwiftUI

struct TabBarScreen: Identifiable {
    var id: String {
        title
    }

    let title: String
    let systemImage: String
    @ViewBuilder var screen: () -> AnyView
}

struct TabBarView<TrainingTabAccessory: View, MealTabAccessory: View, Search: View>: View {

    @State var presenter: TabBarPresenter

    var tabs: [TabBarScreen]
    
    @ViewBuilder var trainingAccessoryView: (TrainingAccessoryDelegate) -> TrainingTabAccessory
    @ViewBuilder var mealAccessoryView: (MealAccessoryDelegate) -> MealTabAccessory
    
    @ViewBuilder var searchView: () -> Search

    /// The search tab is SwiftUI's own, so it has no `TabBarScreen` to take a title from.
    /// Computed rather than `static let`: `TabBarView` is generic, and generic types cannot hold
    /// static stored properties.
    private var searchTabTitle: String { DeepLink.Tab.search.title }

    var body: some View {
        TabView(selection: $presenter.selectedTabTitle) {
            ForEach(tabs) { tab in
                Tab(value: tab.title) {
                    tab.screen()
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .badge(tab.title == DeepLink.Tab.dashboard.title ? presenter.unreadActivityCount : 0)
            }

            Tab(value: searchTabTitle, role: .search) {
                searchView()
            } label: {
                Label(searchTabTitle, systemImage: "magnifyingglass")
            }
        }
        // `compound://tab/nutrition` and the equivalent push payload land here. This is the only
        // place in the app that can switch tabs, so it is the only place that can usefully receive
        // them — the old handler hung off AnalyticsView and navigated nowhere.
        .onOpenURL { url in
            presenter.onOpenURL(url)
        }
        .onNotificationReceived(name: .pushNotification) { _ in
            presenter.onPushNotificationReceived()
        }
        .onAppear {
            presenter.onViewAppear()
        }
        // A screen inside a tab asking for a different tab — see `DeepLink.post()`.
        .onNotificationReceived(name: Constants.selectTab) { notification in
            presenter.onSelectTabNotificationReceived(notification)
        }
        .tabViewStyle(.tabBarOnly)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: presenter.showTabAccessory) {
            ScrollView(.horizontal) {
                HStack(alignment: .center) {
                    if let active = presenter.activeSession {
                        trainingAccessoryView(TrainingAccessoryDelegate(active: active))
                            .frame(width: presenter.tabAccessoryWidth)
                    }
                    if let draftMeal = presenter.draftMeal {
                        mealAccessoryView(MealAccessoryDelegate(draftMeal: draftMeal))
                            .frame(width: presenter.tabAccessoryWidth)
                    }
                }
                //                    .frame(width: geometry.size.height)
                .scrollTargetLayout()
            }
            //                .padding(.horizontal)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            //                .frame(maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            }
            .onPreferenceChange(WidthPreferenceKey.self) { width in
                self.presenter.tabAccessoryWidth = width
            }
        }
    }
}

struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 400
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension CoreBuilder {
    
    func tabBarView(router: AnyRouter) -> some View {
        TabBarView(
            presenter: TabBarPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            tabs: tabBarScreens,
            trainingAccessoryView: { delegate in
                self.trainingAccessoryView(router: router, delegate: delegate)
            },
            mealAccessoryView: { delegate in
                self.mealAccessoryView(router: router, delegate: delegate)
            },
            searchView: {
                RouterView { router in
                    self.searchView(router: router)
                }
            }
        )
    }

    /// The four root tabs. Extracted from `tabBarView` so that function stays inside the
    /// body-length limit.
    private var tabBarScreens: [TabBarScreen] {
        [
            TabBarScreen(
                title: String(localized: "Dashboard"),
                systemImage: "house",
                screen: {
                    RouterView { router in
                        self.dashboardView(router: router, delegate: DashboardDelegate())
                    }
                    .any()
                }
            ),
            TabBarScreen(
                title: String(localized: "Training"),
                systemImage: "dumbbell",
                screen: {
                    RouterView { router in
                        self.trainingView(delegate: TrainingDelegate(), router: router)
                    }
                    .any()
                }
            ),
            TabBarScreen(
                title: String(localized: "Nutrition"),
                systemImage: "carrot",
                screen: {
                    RouterView { router in
                        self.nutritionView(delegate: NutritionDelegate(), router: router)
                    }
                    .any()
                }
            ),
            TabBarScreen(
                title: String(localized: "Analytics"),
                systemImage: "chart.bar.xaxis",
                screen: {
                    RouterView { router in
                        self.analyticsView(delegate: AnalyticsDelegate(), router: router)
                    }
                    .any()
                }
            )
        ]
    }

}

#Preview("Has No Active Session") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.tabBarView(router: router)
    }
    
}

#Preview("Has Active Session") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.tabBarView(router: router)
    }
    
}
