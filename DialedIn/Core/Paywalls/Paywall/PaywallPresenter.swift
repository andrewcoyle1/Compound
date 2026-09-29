import SwiftUI
import StoreKit
import RevenueCat

@Observable
@MainActor
class PaywallPresenter {
    
    private let interactor: PaywallInteractor
    private let router: PaywallRouter
    let isOnboarding: Bool

    private(set) var products: [AnyProduct] = []
    private(set) var productIds: [String] = EntitlementOption.allProductIds
    private(set) var isLoadingProducts: Bool = false
    private(set) var loadErrorMessage: String?
    /// The plan chosen on the custom paywall. Subscribe stays disabled until there is one.
    private(set) var selectedProduct: AnyProduct?
    /// Ask to Buy: the purchase is waiting for a parent to approve it. Shown inline, not as an error.
    private(set) var isPurchasePending: Bool = false
    
    var paywallTest: PaywallTestOption {
        interactor.paywallTest
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    enum PaywallLoadError: LocalizedError {
        case noProductsReturned
        
        var errorDescription: String? {
            switch self {
            case .noProductsReturned:
                return String(localized: "No products returned from the store.")
            }
        }
    }

    init(interactor: PaywallInteractor, router: PaywallRouter, isOnboarding: Bool) {
        self.interactor = interactor
        self.router = router
        self.isOnboarding = isOnboarding
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    /// The StoreKit and RevenueCat variants load their own products.
    func onViewTask() async {
        guard paywallTest == .custom else { return }
        await onLoadProducts()
    }

    func onLoadProducts() async {
        isLoadingProducts = true
        loadErrorMessage = nil
        interactor.trackEvent(event: Event.loadProductsStart(variant: paywallTest))
        
        do {
            let fetchedProducts = try await interactor.getProducts(productIds: productIds)
            products = fetchedProducts
            
            if fetchedProducts.isEmpty {
                loadErrorMessage = String(localized: "No subscription options are available right now. Please try again in a moment.")
                interactor.trackEvent(event: Event.loadProductsFail(error: PaywallLoadError.noProductsReturned, variant: paywallTest))
            } else {
                interactor.trackEvent(event: Event.loadProductsSuccess(count: fetchedProducts.count, variant: paywallTest))
            }
        } catch {
            // The screen's own error state says this; an alert on top said it twice.
            loadErrorMessage = error.userFacingMessage
            interactor.trackEvent(event: Event.loadProductsFail(error: error, variant: paywallTest))
        }
        
        isLoadingProducts = false
    }
    func onBackButtonPressed() {
        interactor.trackEvent(event: Event.backButtonPressed)
        router.dismissScreen()
    }
    
    private func onPurchaseSuccess() {
        interactor.playHaptic(option: .success)
        if isOnboarding {
            handleNavigation()
        } else {
            router.dismissEnvironment()
        }
    }
    
    // MARK: Handle Navigation
    func handleNavigation() {
        // Navigate based on user's inferred onboarding step
        if let currentUser = interactor.currentUser {
            let step = currentUser.inferredOnboardingStep

            route(to: step)
        }
    }

    private func route(to step: OnboardingStep) {
        router.routeToOnboardingStep(step, onComplete: handleNavigation)
    }

    func onRestorePurchasePressed() {
        interactor.trackEvent(event: Event.restorePurchaseStart)

        Task {
            do {
                let entitlements = try await interactor.restorePurchase()
                
                if entitlements.hasActiveEntitlement {
                    onPurchaseSuccess()
                } else {
                    // A restore that finds nothing does not throw, so this branch raised nothing
                    // at all and the button read as dead. It is the commonest restore outcome —
                    // wrong Apple Account, or a subscription that has lapsed — and it happens on
                    // the one screen a paying customer has to get past.
                    interactor.trackEvent(event: Event.restorePurchaseEmpty)
                    router.showAlert(
                        title: String(localized: "Nothing to Restore"),
                        subtitle: String(localized: "We couldn't find an active subscription on this Apple Account. Check that you are signed in with the account you subscribed with."),
                        buttons: nil
                    )
                }
            } catch {
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Restore Purchases"), error: error)
            }
        }
    }

    func onProductSelected(_ product: AnyProduct) {
        interactor.playHaptic(option: .selection)
        selectedProduct = product
    }

    func onSubscribePressed() {
        guard let selectedProduct else { return }
        onPurchaseProductPressed(product: selectedProduct)
    }

    func onPurchaseProductPressed(product: AnyProduct) {
        interactor.trackEvent(event: Event.purchaseStart(product: product))

        Task {
            do {
                let entitlements = try await interactor.purchaseProduct(productId: product.id)
                interactor.trackEvent(event: Event.purchaseSuccess(product: product))

                if entitlements.hasActiveEntitlement {
                    onPurchaseSuccess()
                }
            } catch {
                switch PaywallPresenter.outcome(of: error) {
                case .cancelled:
                    // Closing Apple's purchase sheet is a choice, not a failure.
                    interactor.trackEvent(event: Event.purchaseCancelled(product: product))
                case .pending:
                    interactor.trackEvent(event: Event.purchasePending(product: product))
                    isPurchasePending = true
                case .failed:
                    interactor.trackEvent(event: Event.purchaseFail(error: error))
                    interactor.playHaptic(option: .error)
                    router.showAlert(title: String(localized: "Unable to Complete Purchase"), error: error)
                }
            }
        }
    }
    
    func onPurchaseStart(product: StoreKit.Product) {
        let product = AnyProduct(storeKitProduct: product)
        interactor.trackEvent(event: Event.purchaseStart(product: product))
    }
    
    func onPurchaseComplete(product: StoreKit.Product, result: Result<Product.PurchaseResult, any Error>) {
        let product = AnyProduct(storeKitProduct: product)

        switch result {
        case .success(let value):
            switch value {
            case .success:
                interactor.trackEvent(event: Event.purchaseSuccess(product: product))
                onPurchaseSuccess()
            case .pending:
                interactor.trackEvent(event: Event.purchasePending(product: product))
                isPurchasePending = true
            case .userCancelled:
                interactor.trackEvent(event: Event.purchaseCancelled(product: product))
            default:
                interactor.trackEvent(event: Event.purchaseUnknown(product: product))
            }
        case .failure(let error):
            interactor.trackEvent(event: Event.purchaseFail(error: error))
            interactor.playHaptic(option: .error)
        }
    }
    
    enum PurchaseErrorOutcome { case cancelled, pending, failed }

    /// Sorts a thrown purchase error. The purchase services report cancel and Ask to Buy as
    /// errors: `StoreKitPurchaseService` throws `userCancelledPurchase`, and `failedToPurchase` for
    /// its one other non-success result, `.pending`; RevenueCat throws its cancelled and
    /// payment-pending codes.
    /// ponytail: StoreKitPurchaseService.Error is internal to SwiftfulPurchasing, so its cases are
    /// matched by name; a public error type in the package would replace this.
    static func outcome(of error: Error) -> PurchaseErrorOutcome {
        let nsError = error as NSError
        if nsError.domain == ErrorCode.errorDomain {
            switch nsError.code {
            case ErrorCode.purchaseCancelledError.rawValue: return .cancelled
            case ErrorCode.paymentPendingError.rawValue: return .pending
            default: return .failed
            }
        }
        switch String(describing: error) {
        case "userCancelledPurchase": return .cancelled
        case "failedToPurchase": return .pending
        default: return .failed
        }
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case purchaseStart(product: AnyProduct)
        case purchaseSuccess(product: AnyProduct)
        case purchasePending(product: AnyProduct)
        case purchaseCancelled(product: AnyProduct)
        case purchaseUnknown(product: AnyProduct)
        case purchaseFail(error: Error)
        case loadProductsStart(variant: PaywallTestOption)
        case loadProductsSuccess(count: Int, variant: PaywallTestOption)
        case loadProductsFail(error: Error, variant: PaywallTestOption)
        case restorePurchaseStart
        case restorePurchaseEmpty
        case backButtonPressed

        var eventName: String {
            switch self {
            case .onAppear:             return "PaywallView_Appear"
            case .onDisappear:          return "PaywallView_Disappear"
            case .purchaseStart:        return "PaywallView_Purchase_Start"
            case .purchaseSuccess:      return "PaywallView_Purchase_Success"
            case .purchasePending:      return "PaywallView_Purchase_Pending"
            case .purchaseCancelled:    return "PaywallView_Purchase_Cancelled"
            case .purchaseUnknown:      return "PaywallView_Purchase_Unknown"
            case .purchaseFail:         return "PaywallView_Purchase_Fail"
            case .loadProductsStart:    return "PaywallView_Load_Start"
            case .loadProductsSuccess:  return "PaywallView_Load_Success"
            case .loadProductsFail:     return "PaywallView_Load_Fail"
            case .restorePurchaseStart: return "PaywallView_Restore_Start"
            case .restorePurchaseEmpty: return "PaywallView_Restore_Empty"
            case .backButtonPressed:    return "PaywallView_BackButton_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .purchaseStart(product: let product), .purchaseSuccess(product: let product), .purchasePending(product: let product), .purchaseCancelled(product: let product), .purchaseUnknown(product: let product):
                return product.eventParameters
            case .purchaseFail(error: let error):
                return error.eventParameters
            case .loadProductsStart(variant: let variant):
                return [
                    "paywallVariant": variant.rawValue
                ]
            case .loadProductsSuccess(count: let count, variant: let variant):
                return [
                    "productCount": count,
                    "paywallVariant": variant.rawValue
                ]
            case .loadProductsFail(error: let error, variant: let variant):
                return [
                    "paywallVariant": variant.rawValue,
                    "errorDescription": error.localizedDescription
                ]
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .purchaseFail:
                return .severe
            case .loadProductsFail:
                return .severe
            case .restorePurchaseEmpty:
                return .info
            default:
                return .analytic
            }
        }
    }

}
