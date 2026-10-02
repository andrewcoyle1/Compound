//
//  SwiftfulPurchasing+Alias.swift
//  Compound
//
//  Created by Andrew Coyle on 29/01/2026.
//

import SwiftUI

import SwiftfulPurchasing
import SwiftfulPurchasingRevenueCat
typealias PurchaseManager = SwiftfulPurchasing.PurchaseManager
typealias PurchaseProfileAttributes = SwiftfulPurchasing.PurchaseProfileAttributes
typealias PurchasedEntitlement = SwiftfulPurchasing.PurchasedEntitlement
typealias AnyProduct = SwiftfulPurchasing.AnyProduct
typealias MockPurchaseService = SwiftfulPurchasing.MockPurchaseService
typealias StoreKitPurchaseService = SwiftfulPurchasing.StoreKitPurchaseService
typealias RevenueCatPurchaseService = SwiftfulPurchasingRevenueCat.RevenueCatPurchaseService

extension PurchaseLogType {

    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }

}
extension LogManager: @retroactive PurchaseLogger {

    public func trackEvent(event: any PurchaseLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }

}

extension CoreInteractor {
    // MARK: PurchaseManager
        
    var entitlements: [PurchasedEntitlement] {
        purchaseManager.entitlements
    }
    
    var isPremium: Bool {
        PremiumAccess.isPremium(
            entitlements: entitlements,
            entitlementsAreResolved: premiumEntitlementResolution.isResolved,
            developmentOverride: PremiumOverride.isEnabled
        )
    }
    
    func getProducts(productIds: [String]) async throws -> [AnyProduct] {
        try await purchaseManager.getProducts(productIds: productIds)
    }
    
    func restorePurchase() async throws -> [PurchasedEntitlement] {
        try await purchaseManager.restorePurchase()
    }
    
    func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement] {
        try await purchaseManager.purchaseProduct(productId: productId)
    }
    
    func updateProfileAttributes(attributes: PurchaseProfileAttributes) async throws {
        try await purchaseManager.updateProfileAttributes(attributes: attributes)
    }

}
