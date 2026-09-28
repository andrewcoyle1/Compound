//
//  WelcomeView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI

struct WelcomeDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct WelcomeView: View {

    @State var presenter: WelcomePresenter
    let delegate: WelcomeDelegate

    var body: some View {
        VStack(spacing: Spacing.s) {
            ImageLoaderView(urlString: presenter.imageName)
                .ignoresSafeArea()

            titleSection
                .padding(.top, Spacing.xl)

            Spacer()

            policyLinks
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        #if DEV || MOCK
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    presenter.onDevSettingsPressed()
                } label: {
                    Image(systemName: Symbol.info)
                }
                .accessibilityLabel("Developer settings")
            }
        }
        #endif
        .bottomCTA {
            CallToActionButton {
                presenter.onContinuePressed()
            } label: {
                Text("Get Started")
            }
            .accessibilityIdentifier("GetStartedButton")
            .disabled(presenter.currentUser == nil)
        }
    }

    private var titleSection: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "chart.bar.fill")
                .iconSize(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Compound")
                .font(.display)
            Text("Every rep compounds.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
    }

    /// Force-unwrapped `URL(string:)` before — a typo in either constant would have crashed the
    /// first screen of the app.
    private var policyLinks: some View {
        HStack(spacing: Spacing.s) {
            if let url = LegalDocument.termsOfService.url {
                Link(LegalDocument.termsOfService.title, destination: url)
            }

            Text(verbatim: "·")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if let url = LegalDocument.privacyPolicy.url {
                Link(LegalDocument.privacyPolicy.title, destination: url)
            }
        }
        .font(.rowDetail)
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    builder.onboardingFlow()
}

extension CoreBuilder {
    
    func onboardingFlow() -> some View {
        RouterView { router in
            self.welcomeView(router: router)
        }
    }
    
    private func welcomeView(router: AnyRouter, delegate: WelcomeDelegate = WelcomeDelegate()) -> some View {
        WelcomeView(
            presenter: WelcomePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}
