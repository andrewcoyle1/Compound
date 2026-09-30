//
//  CreatePlanView.swift
//  DialedIn
//

import SwiftUI

struct CreatePlanView: View {

    @State var presenter: CreatePlanPresenter

    var body: some View {
        List {
            Section("Name") {
                TextField("Plan name", text: $presenter.name)
            }
            blocksSection
            programsSection
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("New Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
        }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.onStartPressed()
            } label: {
                Text("Start Plan")
            }
            .disabled(!presenter.canStart)
        }
        .onAppear { presenter.onViewAppear() }
    }

    private var blocksSection: some View {
        Section {
            if presenter.blocks.isEmpty {
                Text("Add programs below. Each one is a block, run in this order.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.blocks, id: \.index) { block in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Block \(block.index + 1)")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    TrainingProgramHeader(program: block.program)
                }
            }
            .onMove { presenter.onMoveBlocks(from: $0, to: $1) }
            .onDelete { presenter.onDeleteBlocks(at: $0) }
        } header: {
            Text("Blocks")
        } footer: {
            Text("After the last block you can repeat the plan from the first one.")
        }
    }

    private var programsSection: some View {
        Section("Your Programs") {
            if presenter.programs.isEmpty {
                Text("Create or start a program first, then build a plan from it.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.programs) { program in
                HStack {
                    TrainingProgramHeader(program: program)
                    Spacer()
                    Image(systemName: Symbol.add)
                        .iconSize(.small)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .anyButton {
                    presenter.onProgramPressed(program)
                }
                .accessibilityHint("Adds this program as the next block")
            }
        }
    }
}

extension CoreBuilder {
    func createPlanView(router: AnyRouter) -> some View {
        CreatePlanView(
            presenter: CreatePlanPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showCreatePlanView() {
        router.showScreen(.sheetConfig(config: .full)) { router in
            builder.createPlanView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createPlanView(router: router)
    }
}
