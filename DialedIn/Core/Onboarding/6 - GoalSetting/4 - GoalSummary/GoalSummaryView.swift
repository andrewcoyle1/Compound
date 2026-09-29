//
//  GoalSummaryView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 07/10/2025.
//

import SwiftUI

struct GoalSummaryDelegate {
    let overarchingObjective: OverarchingObjective
    let targetWeight: Double
    let weightChangeRate: Double
    
    init(overarchingObjective: OverarchingObjective, targetWeight: Double, weightChangeRate: Double) {
        self.overarchingObjective = overarchingObjective
        self.targetWeight = targetWeight
        self.weightChangeRate = weightChangeRate
    }
    
    init(delegate: WeightRateDelegate, weightChangeRate: Double) {
        self.overarchingObjective = delegate.overarchingObjective
        self.targetWeight = delegate.targetWeight
        self.weightChangeRate = weightChangeRate
    }
    
    static var mock: Self {
        Self(delegate: .mock(overarchingObjective: .loseWeight), weightChangeRate: 0.25)
    }
}

struct GoalSummaryView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.goalFlowDismissAction) private var dismissFlow

    @State var presenter: GoalSummaryPresenter

    var delegate: GoalSummaryDelegate

    var body: some View {
        List {
            goalOverviewSection
            weightDetailsSection
            timelineSection
            motivationSection
        }
        .navigationTitle("Goal Summary")
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onDismiss = dismissFlow
        }
        #if DEBUG || MOCK
        .toolbar {
            toolbarContent
        }
        #endif
        .safeAreaInset(edge: .bottom) {
            Group {
                if presenter.isStandaloneMode {
                    CallToActionButton {
                        presenter.onCompletePressed(delegate: delegate)
                    } label: {
                        Text("Complete")
                    }
                    .accessibilityIdentifier("Complete")
                    // Gated on the save being in flight only. It used to also require
                    // `goalCreated`, which nothing ever set — and which only the press of this
                    // button could have set, so Complete was disabled for good.
                    .disabled(presenter.isLoading)
                } else {
                    CallToActionButton {
                        presenter.onContinuePressed(delegate: delegate)
                    } label: {
                        Text("Continue")
                    }
                    .accessibilityIdentifier("Continue")
                    .disabled(presenter.isLoading)
                }
            }
            .padding(.bottom)
        }
    }
    
    #if DEBUG || MOCK
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
    }
    #endif
    
    // MARK: - View Sections
    
    private var goalOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: presenter.objectiveIcon(objective: delegate.overarchingObjective))
                        .font(.title2)
                        .foregroundColor(.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Goal")
                            .font(.headline)
                        Text(objectiveTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                
                Text(objectiveDetail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Goal Overview")
        }
    }
    
    private var weightDetailsSection: some View {
        Section {
            VStack(spacing: 16) {
                if let current = presenter.currentWeight {
                    weightRow(
                        title: String(localized: "Current Weight"),
                        weight: current,
                        unit: presenter.weightUnit
                    )
                }
                
                weightRow(
                    title: String(localized: "Target Weight"),
                    weight: delegate.targetWeight,
                    unit: presenter.weightUnit
                )
                
                if presenter.weightDifference(targetWeight: delegate.targetWeight) != 0 {
                    Divider()
                    
                    HStack {
                        Text("Weight Change")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(presenter.weightDifference(targetWeight: delegate.targetWeight) > 0 ? "+" : "")\(presenter.formatWeight(abs(presenter.weightDifference(targetWeight: delegate.targetWeight)), unit: presenter.weightUnit))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(presenter.weightDifference(targetWeight: delegate.targetWeight) > 0 ? .green : .red)
                    }
                    
                    HStack {
                        Text("Weekly Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(presenter.formatWeight(delegate.weightChangeRate, unit: presenter.weightUnit))/week")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Weight Details")
        }
    }
    
    private var timelineSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated Timeline")
                            .font(.headline)
                        if presenter.estimatedWeeks(delegate: delegate) > 0 {
                            Text("\(presenter.estimatedWeeks(delegate: delegate)) weeks (\(presenter.estimatedMonths(delegate: delegate)) months)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else {
                            Text("Maintaining current weight")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    Spacer()
                }
                
                if presenter.estimatedWeeks(delegate: delegate) > 0 {
                    Text("Based on your selected rate of \(presenter.formatWeight(delegate.weightChangeRate, unit: presenter.weightUnit)) per week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Timeline")
        }
    }
    
    private var motivationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.pink)
                    Text("You've Got This!")
                        .font(.headline)
                    Spacer()
                }
                
                Text(presenter.motivationalMessage(objective: delegate.overarchingObjective))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Motivation")
        }
    }
    
    // MARK: - Helper Methods
    
    private func weightRow(title: String, weight: Double, unit: WeightUnitPreference) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(presenter.formatWeight(weight, unit: unit))
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

private extension GoalSummaryView {
    var objectiveTitle: String {
        delegate.overarchingObjective.description
    }
    
    var objectiveDetail: String {
        delegate.overarchingObjective.detailedDescription
    }
}

extension CoreBuilder {
    func goalSummaryView(router: AnyRouter, delegate: GoalSummaryDelegate) -> some View {
        GoalSummaryView(
            presenter: GoalSummaryPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
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
