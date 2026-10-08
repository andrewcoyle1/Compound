//
//  MacrocyclesView.swift
//  Compound
//

import SwiftUI

struct MacrocyclesView: View {

    @State var presenter: MacrocyclesPresenter

    var body: some View {
        List {
            if let current = presenter.current {
                Section("Following") {
                    row(current)
                }
            }
            if !presenter.others.isEmpty {
                Section("Saved") {
                    ForEach(presenter.others) { row($0) }
                }
            }
        }
        .overlay {
            if presenter.isEmpty {
                ContentUnavailableView {
                    Label("No Macrocycles", systemImage: Symbol.macrocycle)
                } description: {
                    Text("A macrocycle runs your mesocycles one after another.")
                } actions: {
                    Button {
                        presenter.onNewMacrocyclePressed()
                    } label: {
                        Text("New Macrocycle")
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Import Program…") {
                        presenter.onImportProgramPressed()
                    }
                }
            }
        }
        .navigationTitle("Macrocycles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Macrocycle", systemImage: Symbol.macrocycle) {
                        presenter.onNewMacrocyclePressed()
                    }
                    Button("Import Program…", systemImage: "square.and.arrow.down") {
                        presenter.onImportProgramPressed()
                    }
                } label: {
                    Image(systemName: Symbol.add)
                }
                .accessibilityLabel("Add macrocycle")
            }
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    private func row(_ macrocycle: Macrocycle) -> some View {
        ListRowButton(
            title: macrocycle.name,
            subtitle: presenter.subtitle(for: macrocycle),
            systemImage: Symbol.macrocycle
        ) {
            presenter.onMacrocyclePressed(macrocycle)
        }
    }
}

extension CoreBuilder {
    func macrocyclesView(router: AnyRouter) -> some View {
        MacrocyclesView(
            presenter: MacrocyclesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    /// Browsing, so a push on the Training tab's stack.
    func showMacrocyclesView() {
        router.showScreen(.push) { router in
            builder.macrocyclesView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.macrocyclesView(router: router)
    }
}
