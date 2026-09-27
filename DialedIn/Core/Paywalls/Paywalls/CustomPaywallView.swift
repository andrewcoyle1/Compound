//
//  CustomPaywallView.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/1/24.
//

import SwiftUI

struct CustomPaywallView: View {
    
    var products: [AnyProduct] = []
    var title: String = "Try Premium Today!"
    var subtitle: String = "Unlock unlimited access and exclusive features for premium members."
    var onBackButtonPressed: () -> Void = { }
    var onRestorePurchasePressed: () -> Void = { }
    var onPurchaseProductPressed: (AnyProduct) -> Void = { _ in }
    
    @State var selectedProduct: AnyProduct?
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            List(products) { product in
                productRow(product: product)
            }
        }
        .multilineTextAlignment(.center)
        .safeAreaInset(edge: .bottom) {
            subscriptionButtonSection
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: 150)
        .background(Color.accent.gradient)
    }
    
    private func productRow(product: AnyProduct) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.headline)
                    Text(product.priceStringWithDuration)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("START")
                    .badgeButton()
            }
            Divider()
            Text(product.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .foregroundStyle(Color.accentColor)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
        .anyButton(.press, action: {
            selectedProduct = product
        })
        .padding(16)
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }
    
    private var subscriptionButtonSection: some View {
        VStack {
            if let product = selectedProduct {
                Text("Plan auto-renews for \(product.priceStringWithDuration) until cancelled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            CallToActionButton {
                guard let product = selectedProduct else { return }
                onPurchaseProductPressed(product)
            } label: {
                Text("Subscribe")
            }
            restoreButton
        }
        .padding(.bottom)
    }

    /// Its action was an empty closure, so Restore Subscription did nothing at all. Not private so
    /// a test can press it.
    var restoreButton: CallToActionButton<Text> {
        CallToActionButton(isPrimaryAction: false, action: onRestorePurchasePressed) {
            Text("Restore Subscription")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                onBackButtonPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }
    }
}

#Preview {
    RouterView { _ in
        CustomPaywallView(
            products: AnyProduct.mocks
        )
    }
}
