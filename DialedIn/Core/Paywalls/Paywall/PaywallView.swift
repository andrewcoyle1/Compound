import SwiftUI

struct PaywallView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @State var presenter: PaywallPresenter

    var body: some View {
        ZStack {
            switch presenter.paywallTest {
            case .custom:
                if presenter.isLoadingProducts {
                    ProgressView()
                } else if let errorMessage = presenter.loadErrorMessage {
                    VStack(spacing: 12) {
                        Text("Unable to load subscription options")
                            .font(.headline)
                            .foregroundStyle(colorScheme.backgroundPrimary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            Task { await presenter.onLoadProducts() }
                        } label: {
                            Text("Try Again")
                                .foregroundStyle(colorScheme.backgroundPrimary)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding()
                } else if presenter.products.isEmpty {
                    VStack(spacing: 8) {
                        Text("No subscription options available right now.")
                            .font(.headline)
                        Button("Refresh") {
                            Task { await presenter.onLoadProducts() }
                        }
                    }
                } else {
                    CustomPaywallView(
                        products: presenter.products,
                        selectedProduct: presenter.selectedProduct,
                        onBackButtonPressed: {
                            presenter.onBackButtonPressed()
                        },
                        onRestorePurchasePressed: {
                            presenter.onRestorePurchasePressed()
                        },
                        onProductSelected: { product in
                            presenter.onProductSelected(product)
                        },
                        onSubscribePressed: {
                            presenter.onSubscribePressed()
                        }
                    )
                }
            case .revenueCat:
                RevenueCatPaywallView()
            case .storeKit:
                StoreKitPaywallView(
                    productIds: presenter.productIds,
                    onInAppPurchaseStart: presenter.onPurchaseStart,
                    onInAppPurchaseCompletion: { (product, result) in
                        presenter.onPurchaseComplete(product: product, result: result)
                    }
                )
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .task {
            await presenter.onLoadProducts()
        }
        .toolbar {
            if !presenter.isOnboarding {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presenter.onBackButtonPressed()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

extension CoreBuilder {
    func paywallView(router: AnyRouter, isOnboarding: Bool = false) -> some View {
        PaywallView(
            presenter: PaywallPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isOnboarding: isOnboarding
            )
        )
    }
}

extension CoreRouter {

    func showPaywall() {
        router.showScreen(.fullScreenCover) { router in
            builder.paywallView(router: router, isOnboarding: false)
        }
    }

    func showPaywall(isOnboarding: Bool = false) {
        router.showScreen(.push) { router in
            builder.paywallView(router: router, isOnboarding: isOnboarding)
        }
    }
}

#Preview("Custom") {
    let container = DevPreview.shared.container()
    container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(paywallTest: .custom)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.paywallView(router: router)
    }
    
}
#Preview("StoreKit") {
    let container = DevPreview.shared.container()
    container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(paywallTest: .storeKit)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.paywallView(router: router)
    }
    
}
#Preview("RevenueCat") {
    let container = DevPreview.shared.container()
    container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(paywallTest: .revenueCat)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.paywallView(router: router)
    }
    
}
