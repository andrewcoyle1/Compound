import SwiftUI

@MainActor
protocol PaywallInteractor: PaywallExitsInteractor {
    var currentUser: UserModel? { get }
    var paywallTest: PaywallTestOption { get }
    func getProducts(productIds: [String]) async throws -> [AnyProduct]
    func restorePurchase() async throws -> [PurchasedEntitlement]
    func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement]
}

extension CoreInteractor: PaywallInteractor { }
