//
//  AuthView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 03/10/2025.
//

import SwiftUI

struct AuthView: View {

    @Environment(\.colorScheme) private var colorScheme

    @State var presenter: AuthPresenter

    var body: some View {
        VStack {
            imageSection
            Group {
                SignInWithAppleButtonView { presenter.onSignInApplePressed() }
                    .accessibilityIdentifier("Auth.apple")
                SignInWithGoogleButtonView { presenter.onSignInGooglePressed() }
                tsAndCsSection
            }
            .padding(.horizontal)
        }
        .background {
            Color(colorScheme.backgroundPrimary)
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            presenter.cleanUp()
        }
        .safeAreaInset(edge: .top) {
            Text("COMPOUND")
                .font(.system(size: 48))
                .fontDesign(.default)
                .fontWeight(.heavy)
                .foregroundStyle(Color.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    colorScheme.backgroundPrimary.opacity(0.75)
                )
        }
    }

    #if DEBUG || MOCK
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
    }
    #endif

    private var imageSection: some View {
        ImageLoaderView()
            .ignoresSafeArea()
    }

    private var tsAndCsSection: some View {
        // The destinations were the literal strings "Constants.termsofServiceURL" and
        // "Constants.privacyPolicyURL" — no interpolation, so neither link resolved.
        Text("By continuing, you agree to our [Terms of Service](\(Constants.termsofServiceURL)) and [Privacy Policy](\(Constants.privacyPolicyURL))")
            .font(.caption)
            .foregroundStyle(Color.secondary)
            .padding(.top)
            .frame(maxWidth: 408)

    }
}

extension CoreBuilder {
    func authView(router: AnyRouter) -> some View {
        AuthView(
            presenter: AuthPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showAuthView() {
        router.showScreen(.push) { router in
            builder.authView(router: router)
        }
    }
}

#Preview("Functioning Auth") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        builder.authView(router: router)
    }
    
}

#Preview("Slow Auth") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        builder.authView(router: router)
    }
    
}

#Preview("Failing Auth") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        builder.authView(router: router)
    }
    
}

#Preview("Slow Login") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        builder.authView(router: router)
    }
    
}

#Preview("Failing Login") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        builder.authView(router: router)
    }
    
}
