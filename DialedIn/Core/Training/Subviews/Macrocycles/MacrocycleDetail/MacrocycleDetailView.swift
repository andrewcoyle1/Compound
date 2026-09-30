//
//  MacrocycleDetailView.swift
//  DialedIn
//

import SwiftUI

struct MacrocycleDetailView: View {

    @State var presenter: MacrocycleDetailPresenter

    var body: some View {
        List {
            Section("Name") {
                TextField("Macrocycle name", text: $presenter.name)
            }
            mesocyclesSection
            if !presenter.mesocycleIds.isEmpty {
                startPointSection
            }
            librarySection
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(presenter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.onStartPressed()
            } label: {
                Text(presenter.startButtonTitle)
            }
            .disabled(!presenter.canSave)
        }
        .onAppear { presenter.onViewAppear() }
    }

    private var mesocyclesSection: some View {
        Section {
            if presenter.entries.isEmpty {
                Text("Add mesocycles below. They run in this order.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.entries, id: \.index) { entry in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Mesocycle \(entry.index + 1)")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    MesocycleHeader(mesocycle: entry.mesocycle)
                }
            }
            .onMove { presenter.onMoveMesocycles(from: $0, to: $1) }
            .onDelete { presenter.onDeleteMesocycles(at: $0) }
        } header: {
            Text("Mesocycles")
        } footer: {
            Text("After the last mesocycle you can repeat the macrocycle from the first one.")
        }
    }

    private var startPointSection: some View {
        Section {
            Picker("Mesocycle", selection: $presenter.startMesocycleIndex) {
                ForEach(presenter.entries, id: \.index) { entry in
                    Text("\(entry.index + 1). \(entry.mesocycle.name)").tag(entry.index)
                }
            }
            Picker("Microcycle", selection: $presenter.startMicrocycleIndex) {
                ForEach(0..<presenter.startMicrocycleCount, id: \.self) { index in
                    Text("Microcycle \(index + 1)").tag(index)
                }
            }
        } header: {
            Text("Start At")
        } footer: {
            Text("Joining part-way through? Pick where you are. The microcycles before it count as done.")
        }
    }

    private var librarySection: some View {
        Section("Your Mesocycles") {
            if presenter.library.isEmpty {
                Text("Create or start a mesocycle first, then build a macrocycle from it.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(presenter.library) { mesocycle in
                HStack {
                    MesocycleHeader(mesocycle: mesocycle)
                    Spacer()
                    Image(systemName: Symbol.add)
                        .iconSize(.small)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .anyButton {
                    presenter.onAddMesocyclePressed(mesocycle)
                }
                .accessibilityHint("Adds this mesocycle next")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed()
            }
            .disabled(!presenter.canSave)
        }
        if !presenter.isNew {
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete Macrocycle", systemImage: Symbol.delete, role: .destructive) {
                    presenter.onDeletePressed()
                }
            }
        }
    }
}

extension CoreBuilder {
    func macrocycleDetailView(router: AnyRouter, delegate: MacrocycleDetailDelegate) -> some View {
        MacrocycleDetailView(
            presenter: MacrocycleDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showMacrocycleDetailView(delegate: MacrocycleDetailDelegate) {
        router.showScreen(.push) { router in
            builder.macrocycleDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview("New") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.macrocycleDetailView(router: router, delegate: MacrocycleDetailDelegate())
    }
}
