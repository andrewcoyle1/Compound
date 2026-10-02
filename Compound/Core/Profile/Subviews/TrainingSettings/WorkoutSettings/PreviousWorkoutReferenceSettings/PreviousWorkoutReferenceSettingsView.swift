import SwiftUI

struct PrevWORefSettingsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct PreviousWorkoutReferenceSettingsView: View {
    
    @State var presenter: PrevWORefSettingsPresenter
    let delegate: PrevWORefSettingsDelegate
    
    var body: some View {
        List {
            Section {
                ForEach(presenter.options) { option in
                    optionRow(option)
                }
            } header: {
                Text("Reference Scope")
            } footer: {
                Text("Applies to the previous values shown beside each set while you train.")
            }
        }
        .navigationTitle("Previous Reference")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    /// A checkmark list rather than a `Picker`, so each option can carry the explanation the
    /// option enum already defines as its `subtitle`.
    private func optionRow(_ option: PreviousWorkoutReferenceOption) -> some View {
        SelectableRow(title: option.title, subtitle: option.subtitle, isSelected: presenter.previousWorkoutReference == option) {
            presenter.previousWorkoutReference = option
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = PrevWORefSettingsDelegate()
    
    return RouterView { router in
        builder.previousWorkoutReferenceSettingsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    func previousWorkoutReferenceSettingsView(router: AnyRouter, delegate: PrevWORefSettingsDelegate) -> some View {
        PreviousWorkoutReferenceSettingsView(
            presenter: PrevWORefSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showPreviousWorkoutReferenceSettingsView(delegate: PrevWORefSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.previousWorkoutReferenceSettingsView(router: router, delegate: delegate)
        }
    }
    
}
