//
//  PrebuiltMesocycleDetailView.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2026.
//

import SwiftUI

struct PrebuiltMesocycleDetailView: View {

    @State var presenter: PrebuiltMesocycleDetailPresenter

    var body: some View {
        List {
            Section {
                MesocycleHeader(mesocycle: presenter.mesocycle)
            }
            overviewSection
            daysSection
        }
        .navigationTitle(presenter.mesocycle.name)
        .navigationBarTitleDisplayMode(.inline)
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isStarting) {
                Task { await presenter.onStartPressed() }
            } label: {
                Text("Start Mesocycle")
            }
            .disabled(presenter.isStarting)
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Days per microcycle", value: "\(presenter.mesocycle.workoutTemplates.count)")
            LabeledContent("Workouts per microcycle", value: "\(presenter.workoutCount)")
            LabeledContent("Microcycles", value: "\(presenter.mesocycle.numMicrocycles)")
            LabeledContent("Deload", value: presenter.mesocycle.deload.title)
            LabeledContent("Periodization", value: presenter.mesocycle.periodisation ? String(localized: "On") : String(localized: "Off"))
        }
    }

    private var daysSection: some View {
        Section("Days") {
            ForEach(Array(presenter.mesocycle.workoutTemplates.enumerated()), id: \.element.id) { index, day in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Day \(index + 1)")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    if day.exercises.isEmpty {
                        Label("Rest", systemImage: Symbol.restDay)
                            .font(.rowTitle)
                            .foregroundStyle(.secondary)
                    } else {
                        WorkoutTemplateRow(workoutTemplate: day)
                        ForEach(day.exercises) { exercise in
                            exercisePlan(exercise)
                        }
                    }
                }
            }
        }
    }

    /// "Bench Press" over "Week 1: 2 sets, 8–10 · From week 2: 3 sets, 8–10", or over the one
    /// set of targets when they never change.
    private func exercisePlan(_ exercise: WorkoutTemplateExercise) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(exercise.exercise.name)
                .font(.rowDetail)
                .foregroundStyle(.primary)
            Text(exercise.variationSummary ?? WorkoutTemplateExercise.targetSummary(exercise.setTargets))
                .font(.label)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension CoreBuilder {
    func prebuiltMesocycleDetailView(router: AnyRouter, mesocycle: Mesocycle, onStarted: (@Sendable () -> Void)? = nil) -> some View {
        PrebuiltMesocycleDetailView(
            presenter: PrebuiltMesocycleDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                mesocycle: mesocycle,
                onStarted: onStarted
            )
        )
    }
}

extension CoreRouter {
    func showPrebuiltMesocycleDetailView(mesocycle: Mesocycle) {
        showPrebuiltMesocycleDetailView(mesocycle: mesocycle, onStarted: nil)
    }

    func showPrebuiltMesocycleDetailView(mesocycle: Mesocycle, onStarted: (@Sendable () -> Void)?) {
        router.showScreen(.push) { router in
            builder.prebuiltMesocycleDetailView(router: router, mesocycle: mesocycle, onStarted: onStarted)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.prebuiltMesocycleDetailView(router: router, mesocycle: PrebuiltSeedData.mesocycles.first ?? .mock)
    }
}
