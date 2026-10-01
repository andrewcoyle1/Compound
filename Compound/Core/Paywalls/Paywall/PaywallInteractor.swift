import SwiftUI
import StoreKit

@MainActor
protocol PaywallInteractor: PaywallExitsInteractor {
    var currentUser: UserModel? { get }
    var paywallTest: PaywallTestOption { get }
    func getProducts(productIds: [String]) async throws -> [AnyProduct]
    func restorePurchase() async throws -> [PurchasedEntitlement]
    func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement]
    func ownsProduct(productId: String) async -> Bool
}

extension CoreInteractor: PaywallInteractor {

    /// Asks StoreKit rather than the purchase service: StoreKit refuses to sell a subscription the
    /// Apple Account already has, and RevenueCat passes that on as an unknown store error, so this
    /// is the only way to tell "already yours" from a real failure.
    func ownsProduct(productId: String) async -> Bool {
        for await _ in StoreKit.Transaction.currentEntitlements(for: productId) {
            return true
        }
        return false
    }
}
