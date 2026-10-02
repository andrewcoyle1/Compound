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
    
    // The constants always parse; the fallback only keeps the modifier's non-optional URL honest.
    private var termsURL: URL { LegalDocument.termsOfService.url ?? URL(fileURLWithPath: "/") }
    private var privacyURL: URL { LegalDocument.privacyPolicy.url ?? URL(fileURLWithPath: "/") }

    var body: some View {
        SubscriptionStoreView(productIDs: productIds) {
            VStack(spacing: Spacing.s) {
                // One product name everywhere: "Compound".
                Text("Compound")
                    .font(.display)

                Text("Personalized plans, smart coaching, progress tracking, Apple Health sync and reminders.")
                    .font(.rowDetail)
            }
            .foregroundStyle(.onAccent)
            .multilineTextAlignment(.center)
            .containerBackground(Color.accentColor.gradient, for: .subscriptionStore)
        }
        .storeButton(.hidden, for: .cancellation)
        .storeButton(.visible, for: .restorePurchases)
        // Terms and Privacy, which the purchase page has to link.
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
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
