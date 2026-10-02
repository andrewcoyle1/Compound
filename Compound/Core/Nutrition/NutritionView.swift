//
//  NutritionView.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI

struct NutritionDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct NutritionView<
    CalendarHeaderView: View,
    MealHeader: View
>: View {
    
    @State var presenter: NutritionPresenter
    let delegate: NutritionDelegate
    let profileTransitionId: String = "profile_button_transition"
    
    @ViewBuilder var calendarHeader: (CalendarHeaderDelegate, Binding<Bool>) -> CalendarHeaderView
    @ViewBuilder var mealHourHeader: (MealHourHeaderDelegate) -> MealHeader
    @Namespace private var namespace

    @State private var isCalendarExpanded = false

    var body: some View {
        List {
            if presenter.isSearching {
                searchResults
            } else {
                if presenter.timelineHours.isEmpty {
                    emptyDaySection
                } else {
                    mealLogSection
                }
                librarySection
                moreSection
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Nutrition")
        .searchable(
            text: $presenter.searchString,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Foods and recipes")
        )
        .minimizingLargeTitleBar()
        .onAppear { presenter.onViewAppear(delegate: delegate) }
        .onDisappear { presenter.onViewDisappear(delegate: delegate) }
        .toolbar {
            toolbarContent
        }
        .safeAreaBar(edge: .top) {
            topSafeAreaSection
        }
    }
    
    @ViewBuilder
    private var topSafeAreaSection: some View {
        VStack(spacing: 0) {
            if presenter.showCalendarWeekBanner {
                calendarHeader(
                    CalendarHeaderDelegate(
                        onDatePressed: { date in
                            presenter.selectedDate = date.startOfDay
                        },
                        markersByDay: {
                            presenter.calorieMarkersByDay()
                        }
                    ),
                    $isCalendarExpanded
                )
            }
            if let dailyTotals = presenter.dailyTotals,
            let dailyTarget = presenter.dailyTarget {
                MacroHeader(
                    dailyTotals: dailyTotals,
                    dailyTarget: dailyTarget,
                    showCaloriesRing: presenter.showCaloriesRing,
                    showProteinRing: presenter.showProteinRing,
                    showFatRing: presenter.showFatRing,
                    showCarbsRing: presenter.showCarbsRing,
                    showOverages: presenter.showOverages
                )
            }
        }
    }
    
    // MARK: - Timeline

    /// The day's meals, an hour at a time. `presenter.timelineHours` has already dropped the empty
    /// hours if the setting asks for it, so there is nothing to filter here.
    private var mealLogSection: some View {
        ForEach(presenter.timelineHours) { timelineHour in
            hourHeaderSection(timelineHour)
            mealSections(timelineHour)
        }
        .listRowSeparator(.hidden)
        .listSectionMargins(.vertical, 0)
        .listSectionSpacing(0)
    }

    private func hourHeaderSection(_ timelineHour: NutritionPresenter.TimelineHour) -> some View {
        Section {
            mealHourHeader(
                MealHourHeaderDelegate(hour: timelineHour.hour, meals: timelineHour.meals)
            )
        }
        .listSectionMargins(.horizontal, 0)
        .padding(.horizontal)
    }

    /// A section per meal, so the items logged together stay grouped under one time.
    private func mealSections(_ timelineHour: NutritionPresenter.TimelineHour) -> some View {
        ForEach(timelineHour.meals) { meal in
            Section {
                ForEach(meal.items) { item in
                    mealItemRow(item, meal: meal)
                }
            }
        }
    }

    private func mealItemRow(_ item: MealItemModel, meal: MealLogModel) -> some View {
        MealItemRowView(
            item: item,
            timestamp: presenter.timestamp(for: item, in: meal),
            style: presenter.mealItemRowStyle,
            onEditPressed: { mealItem in
                presenter.onEditMealItem(mealItem, in: meal)
            }
        )
        // Meal detail, which holds Delete Meal, used to open only from a leading swipe. A tap on
        // the row opens it too; the edit button inside the row keeps its own tap. VoiceOver
        // already reaches it as the swipe's custom action.
        .contentShape(.rect)
        .onTapGesture {
            presenter.onViewMealPressed(meal)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                presenter.deleteMealItem(item, from: meal)
            } label: {
                Label("Delete", systemImage: Symbol.delete)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                presenter.onViewMealPressed(meal)
            } label: {
                Label("Meal", systemImage: Symbol.meal)
            }
        }
        // The same actions for anyone who cannot swipe.
        .contextMenu {
            Button {
                presenter.onViewMealPressed(meal)
            } label: {
                Label("View Meal", systemImage: Symbol.meal)
            }
            Button(role: .destructive) {
                presenter.deleteMealItem(item, from: meal)
            } label: {
                Label("Delete", systemImage: Symbol.delete)
            }
        }
    }

    /// With Hide Empty Hours on and nothing logged, the timeline has no hours and so no add
    /// buttons; this keeps the day's one job reachable.
    private var emptyDaySection: some View {
        Section {
            ContentUnavailableView {
                Label("Nothing Logged", systemImage: Symbol.meal)
            } description: {
                Text("Meals you log for this day appear here.")
            } actions: {
                Button {
                    presenter.onLogMealPressed()
                } label: {
                    Text("Log Meal")
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Library

    /// The foods and recipes the user has made, which were otherwise reachable only from inside
    /// Add Meal.
    private var librarySection: some View {
        Section("Library") {
            ListRowButton(title: String(localized: "Foods"), systemImage: Symbol.food) {
                presenter.onFoodsPressed()
            }
            ListRowButton(title: String(localized: "Recipes"), systemImage: Symbol.recipe) {
                presenter.onRecipesPressed()
            }
        }
    }

    // MARK: - More

    private var moreSection: some View {
        Section {
            ListRowButton(title: "TimelineActions", systemImage: Symbol.more) {
                presenter.onTimelineActionsPressed()
            }
            .accessibilityLabel("Timeline actions")
            ListRowButton(title: String(localized: "Nutrition Overview"), systemImage: Symbol.nutrition) {
                presenter.onNutritionOverviewPressed()
            }
            ListRowButton(title: String(localized: "Customize Food Log"), systemImage: Symbol.settings) {
                presenter.onCustomiseFoodLogPressed()
            }
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var searchResults: some View {
        if presenter.filteredFoods.isEmpty && presenter.filteredRecipes.isEmpty {
            ContentUnavailableView.search(text: presenter.searchString)
                .removeListRowFormatting()
        } else {
            SearchResultSection(title: String(localized: "Recipes"), items: presenter.filteredRecipes) {
                presenter.onRecipeResultPressed($0)
            }
            SearchResultSection(title: String(localized: "Foods"), items: presenter.filteredFoods) {
                presenter.onFoodResultPressed($0)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onLogMealPressed()
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Log meal")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isCalendarExpanded = true
            } label: {
                Image(systemName: Symbol.calendar)
            }
            .accessibilityLabel("Show calendar")
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            ProfileButton(
                action: {
                    presenter.onProfilePressed(transitionId: profileTransitionId, namespace: namespace)
                },
                imageUrl: presenter.userImageUrl
            )
            .matchedTransitionSource(id: profileTransitionId, in: namespace)
        }
    }
}

extension CoreRouter {
    func showNutritionView() {
        router.showScreen(.push) { router in
            builder.nutritionView(delegate: NutritionDelegate(), router: router)
        }
    }
}

extension CoreBuilder {
    func nutritionView(delegate: NutritionDelegate, router: AnyRouter) -> some View {
        NutritionView(
            presenter: NutritionPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            calendarHeader: { delegate, isCalendarExpanded in
                self.calendarHeaderView(
                    router: router,
                    delegate: delegate,
                    isCalendarExpanded: isCalendarExpanded
                )
            },
            mealHourHeader: { delegate in
                self.mealHourHeader(router: router, delegate: delegate)
            }
        )
    }
}

#Preview("No Meals ") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NutritionDelegate()
    RouterView { router in
        builder.nutritionView(delegate: delegate, router: router)
    }
    
}

#Preview("With Meals") {
    let container = DevPreview.shared.container()
    
    let meals = MealLogModel.previewWeekMealsByDay.values.flatMap { $0 }
    let mealLogSyncEngine = CollectionSyncEngine<MealLogModel>(
        remote: MockRemoteCollectionService(collection: meals),
        managerKey: Keys.mealLogManagerKey,
        enableLocalPersistence: false,
        logger: nil
    )
    let draftMealPersistence = MockLocalDocumentPersistence<MealLogModel>()
    let mealLogManager = MealLogManager(draftMealLogPersistence: draftMealPersistence, mealLogSyncEngine: mealLogSyncEngine)
    container.register(MealLogManager.self, service: mealLogManager)
    
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NutritionDelegate()
    return RouterView { router in
        builder.nutritionView(delegate: delegate, router: router)
    }
    .task {
        await mealLogManager.signIn(userId: UserModel.mock.userId)
    }
}
