//
//  TodaysWorkoutCard.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

struct TodaysWorkoutCardDelegate {
    let todaysWorkoutTemplate: WorkoutTemplateModel
}

struct TodaysWorkoutCard: View {
    
    @State var presenter: TodaysWorkoutCardPresenter
    let delegate: TodaysWorkoutCardDelegate
    
    var body: some View {
        Section("Today's Workout") {
            ZStack(alignment: .leading) {
                if presenter.isTodayRestDay {
                    restDayCard
                } else if presenter.isTodayCompleted {
                    workoutCompleted
                } else {
                    startWorkoutCard
                }
            }
        }
        // Again whenever today's workout changes: after a finish, a skip or a new block.
        .task(id: presenter.todaysWorkoutTemplate?.id) {
            await presenter.loadTargets()
        }
    }
    
    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            RestDayCard()
            if let name = presenter.nextWorkoutName {
                Button {
                    presenter.onStartPressed()
                } label: {
                    Label("Start \(name) Instead", systemImage: Symbol.start)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Trains today and marks the rest day skipped")
            }
        }
    }
    
    /// The session's summary once it has synced; the plain card until then.
    @ViewBuilder
    private var workoutCompleted: some View {
        if let summary = presenter.completedSummary {
            WorkoutSummaryCard(title: delegate.todaysWorkoutTemplate.name, summary: summary)
                .anyButton(.press) {
                    presenter.onCompletedSessionPressed()
                }
                .accessibilityHint("Opens today's workout")
        } else {
            WorkoutCompletedCard(template: delegate.todaysWorkoutTemplate)
        }
    }

    private var startWorkoutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TodaysWorkoutCardLabel(
                template: delegate.todaysWorkoutTemplate,
                subtitle: presenter.startSubtitle,
                targets: presenter.targets
            )
                .anyButton(.press) {
                    presenter.onTodaysWorkoutPressed()
                }
                .accessibilityHint("Opens today's workout")
            if presenter.canStart {
                HStack(spacing: Spacing.m) {
                    // Straight into the tracker; the card above still opens the preview.
                    Button {
                        presenter.onStartPressed()
                    } label: {
                        Label("Start Workout", systemImage: Symbol.start)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .foregroundStyle(.onAccent)
                    .accessibilityIdentifier("TodaysWorkoutCard.start")

                    if presenter.canSkip {
                        Button("Skip Workout", systemImage: Symbol.skip) {
                            presenter.onSkipPressed()
                        }
                        .font(.label)
                        .buttonStyle(.borderless)
                        .accessibilityHint("Counts this workout as done and moves the next one up")
                    }
                }
            }
        }
        .contextMenu {
            if presenter.canSkip {
                Button("Skip Workout", systemImage: Symbol.skip) {
                    presenter.onSkipPressed()
                }
            }
        }
    }
}

extension CoreBuilder {
    func todaysWorkoutCard(router: AnyRouter, delegate: TodaysWorkoutCardDelegate) -> some View {
        TodaysWorkoutCard(
            presenter: TodaysWorkoutCardPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = TodaysWorkoutCardDelegate(todaysWorkoutTemplate: .mock)
    
    RouterView { router in
        List {
            builder.todaysWorkoutCard(router: router, delegate: delegate)
        }
    }
}
