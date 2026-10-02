//
//  TabBarView.swift
//  Compound
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

struct TabBarView<TrainingTabAccessory: View, MealTabAccessory: View>: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State var presenter: TabBarPresenter

    /// The selected tab, by `DeepLink.Tab.rawValue`, so the app reopens where it was left. Read back
    /// through `Tab(name:)`, so a scene saved on a tab that has since been renamed still restores.
    @SceneStorage("selectedTab") private var storedTab: String = DeepLink.Tab.today.rawValue

    var tabs: [TabBarScreen]
    
    @ViewBuilder var trainingAccessoryView: (TrainingAccessoryDelegate) -> TrainingTabAccessory
    @ViewBuilder var mealAccessoryView: (MealAccessoryDelegate) -> MealTabAccessory

    var body: some View {
        TabView(selection: $presenter.selectedTab) {
            ForEach(tabs) { tab in
                Tab(value: tab.tab) {
                    tab.screen()
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .badge(tab.tab == .social ? presenter.unreadActivityCount : 0)
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
            presenter.onViewAppear(restoredTab: DeepLink.Tab(name: storedTab))
        }
        .onChange(of: presenter.selectedTab) { _, tab in
            storedTab = tab.rawValue
        }
        // A screen inside a tab asking for a different tab — see `DeepLink.post()`.
        .onNotificationReceived(name: Constants.selectTab) { notification in
            presenter.onSelectTabNotificationReceived(notification)
        }
        .tabViewStyle(.sidebarAdaptable)
        // Screens that lay out wider on iPad and Mac (Today, Social, Progress) read this. Regular width
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
            }
        )
    }

    /// The five root tabs, one job each. Search is not a tab: each tab searches its own content.
    private var tabBarScreens: [TabBarScreen] {
        [
            tabBarScreen(.today, title: String(localized: "Today"), systemImage: "house") { router in
                self.todayView(router: router, delegate: TodayDelegate()).any()
            },
            tabBarScreen(.training, title: String(localized: "Training"), systemImage: "dumbbell") { router in
                self.trainingView(delegate: TrainingDelegate(), router: router).any()
            },
            tabBarScreen(.nutrition, title: String(localized: "Nutrition"), systemImage: "carrot") { router in
                self.nutritionView(delegate: NutritionDelegate(), router: router).any()
            },
            tabBarScreen(.progress, title: String(localized: "Progress"), systemImage: "chart.line.uptrend.xyaxis") { router in
                self.analyticsView(delegate: AnalyticsDelegate(), router: router).any()
            },
            tabBarScreen(.social, title: String(localized: "Social"), systemImage: "person.2") { router in
                self.socialView(router: router, delegate: SocialDelegate()).any()
            }
        ]
    }

    private func tabBarScreen(
        _ tab: DeepLink.Tab,
        title: String,
        systemImage: String,
        root: @escaping (AnyRouter) -> AnyView
    ) -> TabBarScreen {
        TabBarScreen(tab: tab, title: title, systemImage: systemImage) {
            RouterView { router in root(router) }.any()
        }
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
