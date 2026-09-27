//
//  CustomPaywallView.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/1/24.
//

import SwiftUI

struct CustomPaywallView: View {
    
    var products: [AnyProduct] = []
    var selectedProduct: AnyProduct?
    var title: String = "Try Premium Today!"
    var subtitle: String = "Unlock unlimited access and exclusive features for premium members."
    var onRestorePurchasePressed: () -> Void = { }
    var onProductSelected: (AnyProduct) -> Void = { _ in }
    var onSubscribePressed: () -> Void = { }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            List(products) { product in
                productRow(product: product)
            }
        }
        .multilineTextAlignment(.center)
        .bottomCTA {
            subscriptionButtonSection
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: Spacing.s) {
            Text(title)
                .font(.display)

            Text(subtitle)
                .font(.rowDetail)
        }
        .foregroundStyle(.onAccent)
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.accentColor.gradient)
    }
    
    /// A plan card. The selected one is outlined in the accent and carries `.isSelected`.
    private func productRow(product: AnyProduct) -> some View {
        let isSelected = product.id == selectedProduct?.id
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(product.title)
                        .font(.sectionTitle)
                    Text(product.priceStringWithDuration)
                        .font(.rowDetail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Chip("Start", isSelected: isSelected)
            }
            Divider()
            Text(product.subtitle)
                .font(.rowTitle)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.leading)
        .padding()
        .cardSurface()
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        }
        .anyButton(.press) {
            onProductSelected(product)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding()
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }

    private var subscriptionButtonSection: some View {
        VStack(spacing: Spacing.s) {
            if let product = selectedProduct {
                Text("Plan auto-renews for \(product.priceStringWithDuration) until cancelled.")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            // Tapping Subscribe with no plan chosen did nothing and said nothing.
            CallToActionButton(action: onSubscribePressed) {
                Text("Subscribe")
            }
            .disabled(selectedProduct == nil)
            restoreButton
        }
    }

    /// Its action was an empty closure, so Restore Subscription did nothing at all. Not private so
    /// a test can press it.
    var restoreButton: CallToActionButton<Text> {
        CallToActionButton(isPrimaryAction: false, action: onRestorePurchasePressed) {
            Text("Restore Subscription")
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
