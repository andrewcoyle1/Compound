//
//  StravaConnectView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

struct StravaConnectView: View {
    @State var presenter: StravaConnectPresenter

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "figure.run.circle.fill")
                .iconSize(.hero)
                .foregroundStyle(Color.strava)
                .accessibilityHidden(true)

            Text("Connect with Strava")
                .font(.display)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Automatically upload every workout to your Strava account the moment you finish a session.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Strava")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { presenter.onViewAppear() }
        .bottomCTA {
            if presenter.isConnected {
                Label("Strava Connected", systemImage: Symbol.success)
                    .foregroundStyle(Color.success)
                    .font(.sectionTitle)
                    .padding(.bottom, Spacing.s)

                CallToActionButton {
                    presenter.onContinuePressed()
                } label: {
                    Text("Continue")
                }
            } else {
                CallToActionButton(isLoading: presenter.isConnecting) {
                    presenter.onConnectPressed()
                } label: {
                    Text("Connect Strava")
                }
                .tint(Color.strava)

                Button {
                    presenter.onSkipPressed()
                } label: {
                    Text("Skip for now")
                        .padding(.vertical, Spacing.s)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
        }
    }
}

private extension Color {
    /// Strava's brand orange. It stays on this screen: it is Strava's colour, not the app's.
    static let strava = Color.orange
}

extension CoreBuilder {
    func stravaConnectView(router: AnyRouter) -> some View {
        StravaConnectView(
            presenter: StravaConnectPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showStravaConnectView() {
        router.showScreen(.push) { router in
            builder.stravaConnectView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.stravaConnectView(router: router)
    }
}
