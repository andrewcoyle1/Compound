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
                    subtitle: presenter.stravaSubtitle,
                    systemImage: Symbol.cardio,
                    tint: .orange,
                    accessory: .custom(AnyView(stravaAction))
                )
                if presenter.stravaIsConnected {
                    if presenter.backfillCount > 0 {
                        ListRowButton(
                            title: String(localized: "Upload Past Workouts"),
                            subtitle: String(localized: "\(presenter.backfillCount) workouts not on Strava"),
                            systemImage: Symbol.history,
                            accessory: .none
                        ) {
                            presenter.onStravaBackfillPressed()
                        }
                    }
                    if let pending = presenter.pendingUploadsText {
                        ListRow(title: pending, systemImage: Symbol.duration)
                    }
                    #if DEV || MOCK
                    // Posts a real activity to the person's Strava account, so development builds only.
                    HStack {
                        Spacer()
                        if presenter.isTestingStravaUpload {
                            ProgressView()
                        } else {
                            Button("Test Upload") { presenter.onStravaTestUploadPressed() }
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                                .buttonStyle(.borderless)
                        }
                    }
                    #endif
                    Button("Disconnect Strava", role: .destructive) { presenter.onStravaDisconnectPressed() }
                        .disabled(presenter.isDisconnectingStrava)
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
        } else if !presenter.stravaIsConnected {
            // Borderless, so only the button responds rather than the whole row.
            Button("Connect") { presenter.onStravaConnectPressed() }
                .font(.rowDetail)
                .buttonStyle(.borderless)
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
