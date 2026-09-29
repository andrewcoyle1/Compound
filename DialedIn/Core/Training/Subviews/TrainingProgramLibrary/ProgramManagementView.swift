//
//  TrainingProgramLibraryView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 18/10/2025.
//

import SwiftUI

struct TrainingProgramLibraryView<ProgramDisclosure: View, InactiveSection: View>: View {

    @State var presenter: TrainingProgramLibraryPresenter

    @ViewBuilder var trainingProgramDisclosueGroup: (TrainingProgramDisclosureGroupDelegate) -> ProgramDisclosure
    @ViewBuilder var inactiveProgramSection: (InactiveTrainingProgramDelegate) -> InactiveSection
    
    var body: some View {
        List {
            if let activeTrainingProgram = presenter.activeTrainingProgram {
                activeTrainingProgramSection(activeTrainingProgram: activeTrainingProgram)
            }
            if !presenter.nonActiveTrainingPrograms.isEmpty {
                savedProgramsSection
            }
            if presenter.savedPrograms.isEmpty && presenter.activeTrainingProgram == nil {
                emptyState
            }
            if !presenter.prebuiltPrograms.isEmpty {
                templatesSection
            }
        }
        .navigationTitle("My Programs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private func activeTrainingProgramSection(activeTrainingProgram: TrainingProgram) -> some View {
        Section {
            trainingProgramDisclosueGroup(TrainingProgramDisclosureGroupDelegate(trainingProgram: activeTrainingProgram))
        } header: {
            Text("Active Training Program")
        }
    }

    private var savedProgramsSection: some View {
        Section {
            inactiveProgramSection(
                InactiveTrainingProgramDelegate(
                    inactivePrograms: presenter.nonActiveTrainingPrograms,
                    onDelete: { presenter.showDeleteAlert(program: $0) }
                )
            )
        } header: {
            Text("Saved Programs")
        } footer: {
            Text("These are saved program designs. Start a program from a template to generate a scheduled plan.")
        }
    }
    
    private var templatesSection: some View {
        Section {
            ForEach(presenter.prebuiltPrograms) { program in
                HStack {
                    TrainingProgramHeader(program: program)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .anyButton {
                    presenter.onPrebuiltProgramPressed(program)
                }
            }
        } header: {
            Text("Templates")
        } footer: {
            Text("Starting a template saves your own copy and makes it your active program.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Programs", systemImage: "calendar.badge.clock")
        } description: {
            Text("Create your first training program to get started")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presenter.dismissScreen()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                presenter.onCreateProgramPressed()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Create program")
            .buttonStyle(.glassProminent)
        }
    }
}

extension CoreBuilder {
    func trainingProgramLibraryView(router: AnyRouter) -> some View {
        TrainingProgramLibraryView(
            presenter: TrainingProgramLibraryPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            trainingProgramDisclosueGroup: { delegate in
                self.trainingProgramDisclosureGroupView(router: router, delegate: delegate)
            },
            inactiveProgramSection: { delegate in
                self.inactiveTrainingProgramView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showTrainingProgramLibraryView() {
        router.showScreen(.sheet) { router in
            builder.trainingProgramLibraryView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.trainingProgramLibraryView(router: router)
    }
    
}
