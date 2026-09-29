//
//  AuthView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 03/10/2025.
//

import SwiftUI

struct AuthView: View {

    @State var presenter: AuthPresenter

    var body: some View {
        VStack(spacing: Spacing.s) {
            ImageLoaderView()
                .ignoresSafeArea()
            Group {
                SignInWithAppleButtonView { presenter.onSignInApplePressed() }
                    .accessibilityIdentifier("Auth.apple")
                SignInWithGoogleButtonView { presenter.onSignInGooglePressed() }
                tsAndCsSection
            }
            .padding(.horizontal)
        }
        .background {
            Color.surface
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            presenter.cleanUp()
        }
        .safeAreaInset(edge: .top) {
            Text("COMPOUND")
                .font(.display)
                .fontWeight(.heavy)
                .fontDesign(.default)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var tsAndCsSection: some View {
        // The destinations were the literal strings "Constants.termsofServiceURL" and
        // "Constants.privacyPolicyURL" — no interpolation, so neither link resolved.
        Text("By continuing, you agree to our [Terms of Service](\(Constants.termsofServiceURL)) and [Privacy Policy](\(Constants.privacyPolicyURL))")
            .font(.label)
            .foregroundStyle(.secondary)
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
