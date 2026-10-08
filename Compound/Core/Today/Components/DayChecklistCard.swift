//
//  DayChecklistCard.swift
//  Compound
//
//  The day's checklist at the top of Today: each item says whether it is done and opens what
//  gets it done.
//

import SwiftUI

struct DayChecklistCard: View {

    let checklist: TodayChecklist
    let stepGoal: Int
    let onItemPressed: (TodayChecklist.Kind) -> Void
    let onStepGoalSelected: @MainActor @Sendable (Int) -> Void

    var body: some View {
        Section {
            ForEach(checklist.items) { item in
                row(item)
            }
        } header: {
            HStack {
                Text("Your Day")
                Spacer()
                if checklist.isComplete {
                    Chip("Day Complete", systemImage: Symbol.success, tint: .success)
                } else {
                    Text("\(checklist.doneCount) of \(checklist.items.count) done")
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: TodayChecklist.Item) -> some View {
        let button = Button {
            onItemPressed(item.kind)
        } label: {
            ListRow(
                title: title(item.kind),
                subtitle: item.detail,
                systemImage: symbol(item.kind),
                accessory: .custom(AnyView(
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.rowTitle)
                        .foregroundStyle(item.isDone ? AnyShapeStyle(.success) : AnyShapeStyle(.tertiary))
                        .accessibilityHidden(true)
                ))
            )
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
        .accessibilityValue(item.isDone ? Text("Done") : Text("Not done"))

        if item.kind == .steps {
            button.contextMenu {
                // A closure literal, not the stored closure itself: handing a `@MainActor @Sendable`
                // function value to the binding's `@isolated(any)` setter makes Swift 6.3.3 (Xcode
                // 26.6, which CI runs) crash in IR generation on the reabstraction thunk.
                Picker("Step Goal", selection: Binding(get: { stepGoal }, set: { onStepGoalSelected($0) })) {
                    ForEach(TodayPresenter.stepGoalChoices, id: \.self) { goal in
                        Text("\(goal.formatted()) steps").tag(goal)
                    }
                }
            }
        } else {
            button
        }
    }

    private func title(_ kind: TodayChecklist.Kind) -> String {
        switch kind {
        case .training: return String(localized: "Train")
        case .nutrition: return String(localized: "Eat to Target")
        case .weighIn: return String(localized: "Weigh In")
        case .steps: return String(localized: "Steps")
        }
    }

    private func symbol(_ kind: TodayChecklist.Kind) -> String {
        switch kind {
        case .training: return Symbol.workout
        case .nutrition: return Symbol.meal
        case .weighIn: return Symbol.scaleWeight
        case .steps: return Symbol.steps
        }
    }
}

/// A new account's first steps, until they are done or hidden.
struct StarterCard: View {

    let starter: TodayStarter
    let onStepPressed: (TodayStarter.Step) -> Void
    let onDismissed: () -> Void

    var body: some View {
        Section {
            ForEach(starter.remaining) { step in
                ListRowButton(title: step.title, systemImage: symbol(step)) {
                    onStepPressed(step)
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Get Started · \(starter.done.count) of \(TodayStarter.Step.allCases.count)"),
                actionTitle: String(localized: "Hide"),
                padsEdges: false,
                onActionPressed: onDismissed
            )
        }
    }

    private func symbol(_ step: TodayStarter.Step) -> String {
        switch step {
        case .firstWorkout: return Symbol.workout
        case .firstMeal: return Symbol.meal
        case .firstWeighIn: return Symbol.scaleWeight
        case .appleHealth: return Symbol.steps
        case .strava: return Symbol.cardio
        }
    }
}
