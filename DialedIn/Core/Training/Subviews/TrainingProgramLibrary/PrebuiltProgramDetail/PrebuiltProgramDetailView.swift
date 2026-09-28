//
//  PrebuiltProgramDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

import SwiftUI

struct PrebuiltProgramDetailView: View {

    @State var presenter: PrebuiltProgramDetailPresenter

    var body: some View {
        List {
            Section {
                TrainingProgramHeader(program: presenter.program)
            }
            overviewSection
            daysSection
        }
        .navigationTitle(presenter.program.name)
        .navigationBarTitleDisplayMode(.inline)
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isStarting) {
                Task { await presenter.onStartPressed() }
            } label: {
                Text("Start this program")
            }
            .disabled(presenter.isStarting)
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Days per microcycle", value: "\(presenter.program.workoutTemplates.count)")
            LabeledContent("Workouts per microcycle", value: "\(presenter.workoutCount)")
            LabeledContent("Microcycles", value: "\(presenter.program.numMicrocycles)")
            LabeledContent("Deload", value: presenter.program.deload.title)
            LabeledContent("Periodisation", value: presenter.program.periodisation ? String(localized: "On") : String(localized: "Off"))
        }
    }

    private var daysSection: some View {
        Section("Days") {
            ForEach(Array(presenter.program.workoutTemplates.enumerated()), id: \.element.id) { index, day in
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
    func prebuiltProgramDetailView(router: AnyRouter, program: TrainingProgram) -> some View {
        PrebuiltProgramDetailView(
            presenter: PrebuiltProgramDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                program: program
            )
        )
    }
}

extension CoreRouter {
    func showPrebuiltProgramDetailView(program: TrainingProgram) {
        router.showScreen(.push) { router in
            builder.prebuiltProgramDetailView(router: router, program: program)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.prebuiltProgramDetailView(router: router, program: PrebuiltSeedData.programs.first ?? .mock)
    }
}
