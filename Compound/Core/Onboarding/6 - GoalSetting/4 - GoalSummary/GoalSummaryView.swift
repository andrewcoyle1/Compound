//
//  GoalSummaryView.swift
//  Compound
//
//  Created by Andrew Coyle on 07/10/2025.
//

import SwiftUI

struct GoalSummaryDelegate {
    let overarchingObjective: OverarchingObjective
    let targetWeight: Double
    let weightChangeRate: Double
    let isStandaloneMode: Bool
    
    init(overarchingObjective: OverarchingObjective, targetWeight: Double, weightChangeRate: Double, isStandaloneMode: Bool = false) {
        self.overarchingObjective = overarchingObjective
        self.targetWeight = targetWeight
        self.weightChangeRate = weightChangeRate
        self.isStandaloneMode = isStandaloneMode
    }
    
    init(delegate: WeightRateDelegate, weightChangeRate: Double) {
        self.overarchingObjective = delegate.overarchingObjective
        self.targetWeight = delegate.targetWeight
        self.weightChangeRate = weightChangeRate
        self.isStandaloneMode = delegate.isStandaloneMode
    }
    
    static var mock: Self {
        Self(delegate: .mock(overarchingObjective: .loseWeight), weightChangeRate: 0.25)
    }
}

struct GoalSummaryView: View {

    @State var presenter: GoalSummaryPresenter

    var delegate: GoalSummaryDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "Does This Look Right?",
            progress: presenter.isStandaloneMode ? nil : OnboardingStep.goalSetting.progress,
            // Complete saves the goal from settings; Continue carries onboarding on. Either is gated
            // on the save in flight only: it used to also require `goalCreated`, which nothing ever
            // set, so Complete was disabled for good.
            primary: presenter.isStandaloneMode
                ? .init(title: "Complete", isEnabled: !presenter.isLoading, identifier: "Complete") { presenter.onCompletePressed(delegate: delegate) }
                : .init(title: "Continue", isEnabled: !presenter.isLoading, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            goalOverviewSection
            weightDetailsSection
            timelineSection
            motivationSection
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - View Sections

    private var goalOverviewSection: some View {
        Section {
            summaryRow(
                title: "Your Goal",
                value: Text(delegate.overarchingObjective.description),
                detail: Text(delegate.overarchingObjective.detailedDescription),
                systemImage: presenter.objectiveIcon(objective: delegate.overarchingObjective)
            )
        } header: {
            Text("Goal Overview")
        }
    }

    private var weightDetailsSection: some View {
        Section {
            if let current = presenter.currentWeight {
                LabeledContent("Current Weight", value: presenter.formatWeight(current, unit: presenter.weightUnit))
            }
            LabeledContent("Target Weight", value: presenter.formatWeight(delegate.targetWeight, unit: presenter.weightUnit))
            if let change = presenter.weightChange(targetWeight: delegate.targetWeight) {
                LabeledContent("Weight Change") {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: change.isGain ? "arrow.up" : "arrow.down")
                            .accessibilityHidden(true)
                        Text(change.text)
                    }
                }
                LabeledContent("Weekly Rate", value: presenter.weeklyRateText(delegate: delegate))
            }
        } header: {
            Text("Weight Details")
        }
        .font(.rowDetail)
    }

    private var timelineSection: some View {
        Section {
            if presenter.estimatedWeeks(delegate: delegate) > 0 {
                summaryRow(
                    title: "Estimated Timeline",
                    value: Text(presenter.estimatedTimelineText(delegate: delegate)),
                    detail: Text("Based on your selected rate of \(presenter.formatWeight(delegate.weightChangeRate, unit: presenter.weightUnit)) per week"),
                    systemImage: Symbol.calendar
                )
            } else {
                summaryRow(title: "Estimated Timeline", value: Text("Maintaining current weight"), detail: nil, systemImage: Symbol.calendar)
            }
        } header: {
            Text("Timeline")
        }
    }

    private var motivationSection: some View {
        Section {
            summaryRow(
                title: "You've Got This!",
                value: nil,
                detail: Text(presenter.motivationalMessage(objective: delegate.overarchingObjective)),
                systemImage: "heart.fill"
            )
        } header: {
            Text("Motivation")
        }
    }

    // MARK: - Helper Methods

    private func summaryRow(title: LocalizedStringKey, value: Text?, detail: Text?, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Image(systemName: systemImage)
                    .iconSize(.medium)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.sectionTitle)
                    if let value {
                        value
                            .font(.metric)
                    }
                }
            }
            if let detail {
                detail
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.s)
    }

}

extension CoreBuilder {
    func goalSummaryView(router: AnyRouter, delegate: GoalSummaryDelegate) -> some View {
        GoalSummaryView(
            presenter: GoalSummaryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isStandaloneMode: delegate.isStandaloneMode
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showGoalSummaryView(delegate: GoalSummaryDelegate) {
        router.showScreen(.push) { router in
            builder.goalSummaryView(router: router, delegate: delegate)
        }
    }
}

#Preview("Normal") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.goalSummaryView(
            router: router, 
            delegate: .mock
        )
    }
    
}
