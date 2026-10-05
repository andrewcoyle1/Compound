//
//  TodayView.swift
//  Compound
//

import SwiftUI

struct TodayDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

/// The user's own day: a checklist to complete, then what is next — the check-in, today's workout,
/// an evening protein reminder, last week's review — then the week's streak and friends who trained.
struct TodayView<TodaysCard: View, StreakCard: View>: View {

    @State var presenter: TodayPresenter
    let delegate: TodayDelegate

    let profileTransitionId: String = "profile_button_transition"

    @ViewBuilder var todaysWorkoutCard: (TodaysWorkoutCardDelegate) -> TodaysCard
    @ViewBuilder var workoutStreakCard: (WorkoutStreakDelegate) -> StreakCard

    @Namespace private var namespace

    var body: some View {
        let checklist = presenter.checklist
        Dashboard {
            if presenter.showsStarter {
                StarterCard(
                    starter: presenter.starter,
                    onStepPressed: { presenter.onStarterStepPressed($0) },
                    onDismissed: { presenter.onStarterDismissed() }
                )
            }
            DayChecklistCard(
                checklist: checklist,
                stepGoal: presenter.stepGoal,
                onItemPressed: { presenter.onChecklistItemPressed($0) },
                onStepGoalSelected: { presenter.onStepGoalSelected($0) }
            )
            if presenter.dueCheckInWeekStart != nil {
                Section { checkInCard }
            }
            workoutCard
            if let gap = presenter.proteinGapText {
                proteinGapCard(gap)
            }
            if presenter.showsWeeklyReviewCard {
                Section {
                    ListRowButton(title: String(localized: "Your weekly review is ready"), systemImage: "chart.bar.doc.horizontal") {
                        presenter.onWeeklyReviewPressed()
                    }
                }
            }
            workoutStreakCard(WorkoutStreakDelegate())
            if let pulse = presenter.socialPulseText {
                Section {
                    ListRowButton(title: pulse, systemImage: Symbol.friends) {
                        presenter.onSocialPulsePressed()
                    }
                }
            }
        }
        .onChange(of: checklist.isComplete, initial: true) { _, isComplete in
            presenter.onChecklistCompletionChanged(isComplete: isComplete)
        }
        .scrollIndicators(.hidden)
        // No subtitle: it shrinks the large title, which every other tab root shows full size.
        .navigationTitle("Today")
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
            // Without a plan for today the section stays, so the first card is always the workout.
            Section("Today's Workout") {
                ContentUnavailableView {
                    Label(
                        presenter.hasActiveMesocycle ? "Nothing Scheduled" : "No Active Mesocycle",
                        systemImage: presenter.hasActiveMesocycle ? Symbol.rest : Symbol.mesocycle
                    )
                } description: {
                    Text("Start an empty workout and add exercises as you go.")
                } actions: {
                    Button {
                        presenter.onStartEmptyWorkoutPressed()
                    } label: {
                        Text("Start Empty Workout")
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    if !presenter.hasActiveMesocycle {
                        Button("Choose Mesocycle") {
                            presenter.onChooseMesocyclePressed()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var macrocycleCompleteCard: some View {
        Section("Today's Workout") {
            ContentUnavailableView {
                Label("\(presenter.completedMacrocycleName) complete", systemImage: Symbol.success)
            } description: {
                Text("Every mesocycle is done. Run it again from the first one, or pick something new.")
            } actions: {
                Button {
                    presenter.onRepeatMacrocyclePressed()
                } label: {
                    Label("Repeat Macrocycle", systemImage: Symbol.repeatMacrocycle)
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                Button("Choose Mesocycle") {
                    presenter.onChooseMesocyclePressed()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Evening protein

    private func proteinGapCard(_ gap: String) -> some View {
        Section {
            HStack {
                Label(gap, systemImage: Symbol.protein)
                    .font(.rowTitle)
                Spacer()
                Button("Log Meal") {
                    presenter.onProteinGapLogMealPressed()
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

        // The same quick actions the other tabs keep behind their add button.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Log Meal", systemImage: Symbol.meal) {
                    presenter.onLogMealPressed()
                }
                Button("Log Weight", systemImage: Symbol.scaleWeight) {
                    presenter.onLogWeightPressed()
                }
                Button("Start Empty Workout", systemImage: Symbol.workout) {
                    presenter.onStartEmptyWorkoutPressed()
                }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Log")
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
