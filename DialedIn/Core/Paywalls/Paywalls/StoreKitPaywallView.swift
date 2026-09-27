//
//  StoreKitPaywallView.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/1/24.
//
import SwiftUI
import StoreKit

struct StoreKitPaywallView: View {
    
    var productIds: [String] = EntitlementOption.allProductIds
    var onInAppPurchaseStart: ((Product) async -> Void)?
    var onInAppPurchaseCompletion: ((Product, Result<Product.PurchaseResult, any Error>) async -> Void)?
    
    var body: some View {
        SubscriptionStoreView(productIDs: productIds) {
            VStack(spacing: Spacing.s) {
                Text("Compound Pro")
                    .font(.display)

                Text("Get premium access to unlock all features.")
                    .font(.rowDetail)
            }
            .foregroundStyle(.onAccent)
            .multilineTextAlignment(.center)
            .containerBackground(Color.accentColor.gradient, for: .subscriptionStore)
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStoreControlStyle(.prominentPicker)
        .onInAppPurchaseStart(perform: onInAppPurchaseStart)
        .onInAppPurchaseCompletion(perform: onInAppPurchaseCompletion)
    }
}

#Preview {
    StoreKitPaywallView(
        onInAppPurchaseStart: nil,
        onInAppPurchaseCompletion: nil
    )
}
