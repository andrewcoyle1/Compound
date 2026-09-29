import SwiftUI

struct IntegrationsDelegate {
    
}

struct IntegrationsView: View {
    
    @State var presenter: IntegrationsPresenter
    let delegate: IntegrationsDelegate
    
    var body: some View {
        List {
            Section {
                ListRow(
                    title: String(localized: "Strava"),
                    subtitle: presenter.stravaIsConnected ? String(localized: "Connected") : String(localized: "Not connected"),
                    systemImage: Symbol.cardio,
                    tint: .orange,
                    accessory: .custom(AnyView(stravaAction))
                )
                if presenter.stravaIsConnected {
                    HStack {
                        Spacer()
                        if presenter.isTestingStravaUpload {
                            ProgressView()
                        } else {
                            Button("Test Upload") { presenter.onStravaTestUploadPressed() }
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Available Integrations")
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    @ViewBuilder
    private var stravaAction: some View {
        if presenter.isConnectingStrava {
            ProgressView()
        } else if presenter.stravaIsConnected {
            Button("Disconnect", role: .destructive) { presenter.onStravaDisconnectPressed() }
                .font(.rowDetail)
        } else {
            Button("Connect") { presenter.onStravaConnectPressed() }
                .font(.rowDetail)
        }
    }
}

extension CoreBuilder {
    
    func integrationsView(router: AnyRouter, delegate: IntegrationsDelegate) -> some View {
        IntegrationsView(
            presenter: IntegrationsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showIntegrationsView(delegate: IntegrationsDelegate) {
        router.showScreen(.push) { router in
            builder.integrationsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = IntegrationsDelegate()
    
    return RouterView { router in
        builder.integrationsView(router: router, delegate: delegate)
    }
    
}
