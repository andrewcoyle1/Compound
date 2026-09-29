import SwiftUI

struct SmartProgressionSettingsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct SmartProgressionSettingsView: View {
    
    @State var presenter: SmartProgressionSettingsPresenter
    let delegate: SmartProgressionSettingsDelegate
    
    var body: some View {
        List {
            Section {
                CustomLabelButtonView(
                    symbolName: "book.pages",
                    title: String(localized: "Initial log fill"),
                    subtitle: presenter.initialLogFill.title) {
                        editMenu(
                            options: presenter.initialLogFillOptions,
                            selection: presenter.initialLogFill,
                            title: \.title,
                            onSelect: { presenter.initialLogFill = $0 }
                        )
                    }
                CustomToggleView(
                    symbolName: "arrow.trianglehead.branch",
                    title: String(localized: "Apply in session"),
                    subtitle: String(localized: "Allow Smart Progression to fill in new values for exercise data entry fields mid-workout"),
                    bool: $presenter.applyInSession
                )
                CustomLabelButtonView(
                    symbolName: "dot.squareshape",
                    title: String(localized: "Adjustment Mode"),
                    subtitle: presenter.adjustmentMode.title) {
                        editMenu(
                            options: presenter.adjustmentModes,
                            selection: presenter.adjustmentMode,
                            title: \.title,
                            onSelect: { presenter.adjustmentMode = $0 }
                        )
                    }
            } header: {
                Text("Behaviour")
            }
        }
        .navigationTitle("Smart Progression")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    /// Keeps the row's "Edit" capsule but makes it a menu, so choosing a value needs no extra
    /// screen for what is a two- or three-way choice.
    private func editMenu<Option: Identifiable & Equatable>(
        options: [Option],
        selection: Option,
        title: KeyPath<Option, String>,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == selection {
                        Label(option[keyPath: title], systemImage: "checkmark")
                    } else {
                        Text(option[keyPath: title])
                    }
                }
            }
        } label: {
            Text("Edit")
                .padding(.horizontal, 8)
                .padding(8)
                .background(Color.secondary.opacity(0.2), in: .capsule)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SmartProgressionSettingsDelegate()
    
    return RouterView { router in
        builder.smartProgressionSettingsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func smartProgressionSettingsView(router: AnyRouter, delegate: SmartProgressionSettingsDelegate) -> some View {
        SmartProgressionSettingsView(
            presenter: SmartProgressionSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showSmartProgressionSettingsView(delegate: SmartProgressionSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.smartProgressionSettingsView(router: router, delegate: delegate)
        }
    }
    
}
