//
//  TodayView.swift
//  DialedIn
//

import SwiftUI

struct TodayDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

/// The user's own day, as a list of sections: what is due this week, then workout, food, weigh-in
/// and streak.
struct TodayView<TodaysCard: View, StreakCard: View>: View {

    @State var presenter: TodayPresenter
    let delegate: TodayDelegate

    let profileTransitionId: String = "profile_button_transition"

    @ViewBuilder var todaysWorkoutCard: (TodaysWorkoutCardDelegate) -> TodaysCard
    @ViewBuilder var workoutStreakCard: (WorkoutStreakDelegate) -> StreakCard

    @Namespace private var namespace

    var body: some View {
        List {
            if presenter.dueCheckInWeekStart != nil {
                Section { checkInCard }
            }
            if presenter.showsWeeklyReviewCard {
                Section { WeeklyReviewCard { presenter.onWeeklyReviewPressed() } }
            }
            workoutCard
            nutritionCard
            weighInCard
            workoutStreakCard(WorkoutStreakDelegate())
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Today")
        .navigationSubtitle(Date.now.formatted(date: .abbreviated, time: .omitted))
        .minimizingLargeTitleBar()
        .onAppear { presenter.onViewAppear(delegate: delegate) }
        .onDisappear { presenter.onViewDisappear(delegate: delegate) }
        .toolbar { toolbarContent }
    }

    // MARK: - Workout

    @ViewBuilder
    private var workoutCard: some View {
        if let template = presenter.todaysWorkoutTemplate {
            todaysWorkoutCard(TodaysWorkoutCardDelegate(todaysWorkoutTemplate: template))
        } else if presenter.isMacrocycleComplete {
            macrocycleCompleteCard
        } else {
            // Without a plan for today the card stays, so the first card is always the workout.
            Section("Today's Workout") {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text(presenter.hasActiveMesocycle ? "Nothing scheduled today." : "No active program.")
                        .font(.rowTitle)
                    Text("Start an empty workout and add exercises as you go.")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        Button {
                        presenter.onStartEmptyWorkoutPressed()
                    } label: {
                        Text("Start Empty Workout")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    if !presenter.hasActiveMesocycle {
                        Button {
                            presenter.onChooseMesocyclePressed()
                        } label: {
                            Text("Choose Program")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var macrocycleCompleteCard: some View {
        Section("Today's Workout") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("\(presenter.completedMacrocycleName) complete")
                    .font(.rowTitle)
                Text("Every block is done. Run it again from the first block, or pick something new.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                Button {
                    presenter.onRepeatMacrocyclePressed()
                } label: {
                    Label("Repeat Plan", systemImage: Symbol.repeatMacrocycle)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    presenter.onChooseMesocyclePressed()
                } label: {
                    Text("Choose Program")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Nutrition

    /// No invented defaults: a target of 0 reads as "no target" throughout `NutritionCard`.
    private var nutritionCard: some View {
        NutritionCard(
            calories: presenter.nutritionTotals?.calories ?? 0,
            calorieTarget: presenter.nutritionTarget?.calories ?? 0,
            proteinGrams: presenter.nutritionTotals?.proteinGrams ?? 0,
            proteinTarget: presenter.nutritionTarget?.proteinGrams ?? 0,
            carbGrams: presenter.nutritionTotals?.carbGrams ?? 0,
            carbTarget: presenter.nutritionTarget?.carbGrams ?? 0,
            fatGrams: presenter.nutritionTotals?.fatGrams ?? 0,
            fatTarget: presenter.nutritionTarget?.fatGrams ?? 0,
            onLogMealTapped: { presenter.onLogMealPressed() }
        )
    }

    // MARK: - Weigh-in

    private var weighInCard: some View {
        Section("Weigh-In") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let weight = presenter.latestWeightText, let date = presenter.latestWeighInDate {
                    Stat(value: weight, label: presenter.hasWeighedInToday
                        ? String(localized: "Logged today")
                        : String(localized: "Last logged \(date.formatted(.relative(presentation: .named)))"))
                } else {
                    Text("No weigh-ins yet.")
                        .font(.rowTitle)
                    Text("A weigh-in a day keeps your trend and targets accurate.")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
                Button {
                    presenter.onLogWeightPressed()
                } label: {
                    Text("Log Weight")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Weekly check-in

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Weekly Check-In Ready")
                .font(.sectionTitle)
            Text("Review the week and update your nutrition targets.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.m) {
                Button {
                    presenter.onStartCheckInPressed()
                } label: {
                    Text("Start")
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                Button("Skip This Week") {
                    presenter.onSkipCheckInPressed()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if DEV || MOCK
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        #endif

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

extension CoreBuilder {

    func todayView(router: AnyRouter, delegate: TodayDelegate) -> some View {
        TodayView(
            presenter: TodayPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            todaysWorkoutCard: { cardDelegate in
                self.todaysWorkoutCard(router: router, delegate: cardDelegate)
            },
            workoutStreakCard: { streakDelegate in
                self.workoutStreakCardView(router: router, delegate: streakDelegate)
            }
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.todayView(router: router, delegate: TodayDelegate())
    }
}
