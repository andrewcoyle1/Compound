import SwiftUI

struct PaywallView: View {
    
    @State var presenter: PaywallPresenter

    var body: some View {
        ZStack {
            switch presenter.paywallTest {
            case .custom:
                if presenter.isLoadingProducts {
                    ProgressView()
                } else if let errorMessage = presenter.loadErrorMessage {
                    ContentUnavailableView {
                        Label("Unable to load subscription options", systemImage: Symbol.error)
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        CallToActionButton {
                            Task { await presenter.onLoadProducts() }
                        } label: {
                            Text("Try Again")
                        }
                    }
                } else if presenter.products.isEmpty {
                    ContentUnavailableView {
                        Label("No subscription options available right now.", systemImage: Symbol.info)
                    } actions: {
                        Button("Refresh") {
                            Task { await presenter.onLoadProducts() }
                        }
                    }
                } else {
                    CustomPaywallView(
                        products: presenter.products,
                        selectedProduct: presenter.selectedProduct,
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
                // Outside onboarding the toolbar already has a close button.
                RevenueCatPaywallView(displayCloseButton: presenter.isOnboarding)
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
        .safeAreaInset(edge: .top) {
            if presenter.isPurchasePending {
                InlineMessage(.info, "Waiting for approval. Your subscription starts once the purchase is approved.")
                    .padding(.horizontal)
            }
        }
        .task {
            await presenter.onViewTask()
        }
        .toolbar {
            if !presenter.isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.onBackButtonPressed()
                    }
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
