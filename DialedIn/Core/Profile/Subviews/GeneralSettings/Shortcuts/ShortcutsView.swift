import SwiftUI
import AppIntents

struct ShortcutsDelegate {
    
}

struct ShortcutsView: View {
    
    @State var presenter: ShortcutsPresenter
    let delegate: ShortcutsDelegate
    
    var body: some View {
        List {
            Section {
                if presenter.quickActions.isEmpty {
                    Text("No shortcuts. The Search tab will show only recent searches until you add one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(presenter.quickActions) { action in
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .onDelete { presenter.onRemove(at: $0) }
                    .onMove { presenter.onMove(from: $0, to: $1) }
                }
            } header: {
                Text("On the Search Tab")
            } footer: {
                Text("Tap Edit to reorder or remove.")
            }

            if !presenter.availableActions.isEmpty {
                Section {
                    ForEach(presenter.availableActions) { action in
                        Button {
                            presenter.onAddPressed(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                } header: {
                    Text("Available")
                }
            }

            // Siri and the Shortcuts app are the system's own list, from `DialedInAppShortcuts`.
            Section {
                ShortcutsLink()
            } header: {
                Text("Siri & Shortcuts")
            }

            if !presenter.isShowingDefaults {
                Section {
                    Button("Restore Defaults") {
                        presenter.onRestoreDefaultsPressed()
                    }
                }
            }
        }
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        // An EditButton rather than a forced `editMode`: in edit mode a `Button` row can stop
        // responding to taps, which would break the Available section below.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        // No confirm button: each change saves as it is made, like every other settings screen here.
    }
}

extension CoreBuilder {
    
    func shortcutsView(router: AnyRouter, delegate: ShortcutsDelegate) -> some View {
        ShortcutsView(
            presenter: ShortcutsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showShortcutsView(delegate: ShortcutsDelegate) {
        router.showScreen(.push) { router in
            builder.shortcutsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ShortcutsDelegate()
    
    return RouterView { router in
        builder.shortcutsView(router: router, delegate: delegate)
    }
    
}
