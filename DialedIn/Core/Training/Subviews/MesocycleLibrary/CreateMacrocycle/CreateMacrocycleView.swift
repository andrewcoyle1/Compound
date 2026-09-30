//
//  CreateMacrocycleView.swift
//  DialedIn
//

import SwiftUI

struct CreateMacrocycleView: View {

    @State var presenter: CreateMacrocyclePresenter

    var body: some View {
        List {
            Section("Name") {
                TextField("Macrocycle name", text: $presenter.name)
            }
            blocksSection
            mesocyclesSection
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("New Macrocycle")
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
                Text("Start Macrocycle")
            }
            .disabled(!presenter.canStart)
        }
        .onAppear { presenter.onViewAppear() }
    }

    private var blocksSection: some View {
        Section {
            if presenter.blocks.isEmpty {
                Text("Add mesocycles below. They run in this order.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.blocks, id: \.index) { block in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Mesocycle \(block.index + 1)")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    MesocycleHeader(mesocycle: block.mesocycle)
                }
            }
            .onMove { presenter.onMoveBlocks(from: $0, to: $1) }
            .onDelete { presenter.onDeleteBlocks(at: $0) }
        } header: {
            Text("Mesocycles")
        } footer: {
            Text("After the last mesocycle you can repeat the macrocycle from the first one.")
        }
    }

    private var mesocyclesSection: some View {
        Section("Your Mesocycles") {
            if presenter.mesocycles.isEmpty {
                Text("Create or start a mesocycle first, then build a macrocycle from it.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.mesocycles) { mesocycle in
                HStack {
                    MesocycleHeader(mesocycle: mesocycle)
                    Spacer()
                    Image(systemName: Symbol.add)
                        .iconSize(.small)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .anyButton {
                    presenter.onMesocyclePressed(mesocycle)
                }
                .accessibilityHint("Adds this mesocycle next")
            }
        }
    }
}

extension CoreBuilder {
    func createMacrocycleView(router: AnyRouter) -> some View {
        CreateMacrocycleView(
            presenter: CreateMacrocyclePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showCreateMacrocycleView() {
        router.showScreen(.sheetConfig(config: .full)) { router in
            builder.createMacrocycleView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createMacrocycleView(router: router)
    }
}
