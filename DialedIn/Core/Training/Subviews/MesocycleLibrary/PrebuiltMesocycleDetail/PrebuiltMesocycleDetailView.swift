//
//  PrebuiltMesocycleDetailView.swift
//  DialedIn
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
                    }
                }
            }
        }
    }
}

extension CoreBuilder {
    func prebuiltMesocycleDetailView(router: AnyRouter, mesocycle: Mesocycle) -> some View {
        PrebuiltMesocycleDetailView(
            presenter: PrebuiltMesocycleDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                mesocycle: mesocycle
            )
        )
    }
}

extension CoreRouter {
    func showPrebuiltMesocycleDetailView(mesocycle: Mesocycle) {
        router.showScreen(.push) { router in
            builder.prebuiltMesocycleDetailView(router: router, mesocycle: mesocycle)
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
