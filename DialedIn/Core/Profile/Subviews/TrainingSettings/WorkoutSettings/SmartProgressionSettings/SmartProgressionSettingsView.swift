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
                optionPicker("Initial log fill", systemImage: "book.pages", options: presenter.initialLogFillOptions, selection: $presenter.initialLogFill, optionTitle: \.title)
                ListRowToggle(
                    title: String(localized: "Apply in session"),
                    subtitle: String(localized: "Allow Smart Progression to fill in new values for exercise data entry fields mid-workout"),
                    systemImage: "arrow.trianglehead.branch",
                    isOn: $presenter.applyInSession
                )
                optionPicker("Adjustment Mode", systemImage: "dot.squareshape", options: presenter.adjustmentModes, selection: $presenter.adjustmentMode, optionTitle: \.title)
            } header: {
                Text("Behavior")
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

    /// An inline menu picker: each is a two- or three-way choice, so it needs no extra screen.
    private func optionPicker<Option: Identifiable & Hashable>(
        _ title: LocalizedStringKey,
        systemImage: String,
        options: [Option],
        selection: Binding<Option>,
        optionTitle: KeyPath<Option, String>
    ) -> some View {
        Picker(selection: selection) {
            ForEach(options) { option in
                Text(option[keyPath: optionTitle]).tag(option)
            }
        } label: {
            Label(title, systemImage: systemImage)
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
