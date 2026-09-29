//
//  TabBarView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/5/24.
//

import SwiftUI

struct TabBarScreen: Identifiable {
    var id: DeepLink.Tab {
        tab
    }

    let tab: DeepLink.Tab
    let title: String
    let systemImage: String
    @ViewBuilder var screen: () -> AnyView
}

struct TabBarView<TrainingTabAccessory: View, MealTabAccessory: View, Search: View>: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State var presenter: TabBarPresenter

    /// The selected tab, by `DeepLink.Tab.rawValue`, so the app reopens where it was left.
    @SceneStorage("selectedTab") private var storedTab: String = DeepLink.Tab.dashboard.rawValue

    var tabs: [TabBarScreen]
    
    @ViewBuilder var trainingAccessoryView: (TrainingAccessoryDelegate) -> TrainingTabAccessory
    @ViewBuilder var mealAccessoryView: (MealAccessoryDelegate) -> MealTabAccessory
    
    @ViewBuilder var searchView: () -> Search

    var body: some View {
        TabView(selection: $presenter.selectedTab) {
            ForEach(tabs) { tab in
                Tab(value: tab.tab) {
                    tab.screen()
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .badge(tab.tab == .dashboard ? presenter.unreadActivityCount : 0)
            }

            // The search tab is SwiftUI's own, so it has no `TabBarScreen` to take a title from.
            Tab(value: DeepLink.Tab.search, role: .search) {
                searchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
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
            presenter.onViewAppear(restoredTab: DeepLink.Tab(rawValue: storedTab))
        }
        .onChange(of: presenter.selectedTab) { _, tab in
            storedTab = tab.rawValue
        }
        // A screen inside a tab asking for a different tab — see `DeepLink.post()`.
        .onNotificationReceived(name: Constants.selectTab) { notification in
            presenter.onSelectTabNotificationReceived(notification)
        }
        .tabViewStyle(.sidebarAdaptable)
        // Screens that lay out wider on iPad and Mac (Dashboard, Analytics) read this. Regular width
        // is where `.sidebarAdaptable` shows the sidebar.
        .layoutMode(horizontalSizeClass == .compact ? .tabBar : .splitView)
        .tabBarMinimizeBehavior(.onScrollDown)
        // A workout in progress and a draft meal can both exist; only the workout shows here —
        // the draft meal stays reachable from the Nutrition tab. No horizontal scroll: the
        // second item used to sit off-screen with no indicator that it was there.
        .tabViewBottomAccessory(isEnabled: presenter.showTabAccessory) {
            if let active = presenter.activeSession {
                trainingAccessoryView(TrainingAccessoryDelegate(active: active))
            } else if let draftMeal = presenter.draftMeal {
                mealAccessoryView(MealAccessoryDelegate(draftMeal: draftMeal))
            }
        }
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
                tab: .dashboard,
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
                tab: .training,
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
                tab: .nutrition,
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
                tab: .analytics,
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
