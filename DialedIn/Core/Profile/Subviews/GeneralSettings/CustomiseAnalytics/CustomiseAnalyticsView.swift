import SwiftUI

struct CustomiseAnalyticsDelegate {
    
}

struct CustomiseAnalyticsView: View {
    
    @State var presenter: CustomiseAnalyticsPresenter
    let delegate: CustomiseAnalyticsDelegate
    
    var body: some View {
        List {
            Section {
                ForEach(presenter.sections) { section in
                    Toggle(isOn: visibility(for: section)) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                    .disabled(!presenter.canHide(section))
                }
            } header: {
                Text("Sections")
            } footer: {
                Text("Turn a section off to hide it from the Analytics tab. Everything stays reachable from the More list at the bottom of the tab.")
            }

            if presenter.hiddenCount > 0 {
                Section {
                    Button("Show All Sections") {
                        presenter.onShowAllPressed()
                    }
                }
            }
        }
        .navigationTitle("Customize Analytics")
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationBarTitleDisplayMode(.inline)
        // No confirm button: each toggle saves as it changes, the same as every other settings screen
        // here. The one that used to sit in this toolbar had an empty action.
    }

    /// The toggle reads and writes through the presenter rather than binding to the model, so the
    /// save fires on every change.
    private func visibility(for section: AnalyticsSection) -> Binding<Bool> {
        Binding(
            get: { presenter.isVisible(section) },
            set: { presenter.setVisible($0, for: section) }
        )
    }
}

extension CoreBuilder {
    
    func customiseAnalyticsView(router: AnyRouter, delegate: CustomiseAnalyticsDelegate) -> some View {
        CustomiseAnalyticsView(
            presenter: CustomiseAnalyticsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate) {
        router.showScreen(.push) { router in
            builder.customiseAnalyticsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = CustomiseAnalyticsDelegate()
    
    return RouterView { router in
        builder.customiseAnalyticsView(router: router, delegate: delegate)
    }
    
}
