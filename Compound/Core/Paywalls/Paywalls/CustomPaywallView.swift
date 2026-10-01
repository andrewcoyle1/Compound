//
//  CustomPaywallView.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/1/24.
//

import SwiftUI
import StoreKit

struct CustomPaywallView: View {
    
    var products: [AnyProduct] = []
    var selectedProduct: AnyProduct?
    var onRestorePurchasePressed: () -> Void = { }
    var onProductSelected: (AnyProduct) -> Void = { _ in }
    var onSubscribePressed: () -> Void = { }
    
    var body: some View {
        // The header scrolls with the plans, so at large text sizes on a small phone it cannot
        // squeeze them out of view.
        List {
            Section {
                headerSection
                    .removeListRowFormatting()
                    .listRowSeparator(.hidden)
            }
            // The plans first, so the price and the choice are on screen without scrolling.
            ForEach(products) { product in
                productRow(product: product)
            }
            Section {
                SubscriptionFeatureRows()
            } header: {
                Text("Included")
            }
        }
        // A bar rather than `.bottomCTA`: the renewal line and the legal links are small text, and
        // the bar's scroll-edge effect keeps the plans scrolling under them from showing through.
        .safeAreaBar(edge: .bottom) {
            subscriptionButtonSection
                .padding(.bottom, Spacing.s)
                #if targetEnvironment(macCatalyst)
                // Catalyst draws no scroll-edge effect here (`.hard` included), so the rows read
                // straight through the renewal line and buttons.
                .background(Color.canvas)
                #endif
        }
    }
    
    /// One product name everywhere: "Compound". No "Try… Today!" and no trial wording, because
    /// there is no trial.
    private var headerSection: some View {
        VStack(spacing: Spacing.s) {
            Text("Compound")
                .font(.display)

            Text("One subscription for training, nutrition and progress.")
                .font(.rowDetail)
        }
        .foregroundStyle(.onAccent)
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.accentColor.gradient)
    }
    
    /// A plan card. The selected one carries the row's selection checkmark, is outlined in the
    /// accent and has `.isSelected`. It used to carry a "Start" chip that started nothing.
    private func productRow(product: AnyProduct) -> some View {
        let isSelected = product.id == selectedProduct?.id
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(product.title)
                        .font(.sectionTitle)
                    Text(product.localizedPriceWithPeriod)
                        .font(.rowDetail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .iconSize(.small)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding()
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }

    private var subscriptionButtonSection: some View {
        VStack(spacing: Spacing.s) {
            if let product = selectedProduct {
                Text("Plan auto-renews for \(product.localizedPriceWithPeriod) until canceled.")
                    .font(.label)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            // Tapping Subscribe with no plan chosen did nothing and said nothing.
            CallToActionButton(action: onSubscribePressed) {
                Text("Subscribe")
            }
            .disabled(selectedProduct == nil)
            restoreButton
            legalLinks
        }
    }

    /// Its action was an empty closure, so Restore Subscription did nothing at all. Not private so
    /// a test can press it.
    var restoreButton: CallToActionButton<Text> {
        CallToActionButton(isPrimaryAction: false, action: onRestorePurchasePressed) {
            Text("Restore Subscription")
        }
    }

    /// The purchase page has to link the terms and the privacy policy.
    private var legalLinks: some View {
        HStack(spacing: Spacing.l) {
            ForEach([LegalDocument.termsOfService, .privacyPolicy]) { document in
                if let url = document.url {
                    Link(destination: url) {
                        Text(document.title)
                            .tapTarget()
                    }
                }
            }
        }
        .font(.label)
    }
}

extension AnyProduct {
    /// "$9.99 / 1 month": the billing period in the system's own localized subscription-period
    /// wording. The package's `priceStringWithDuration` appended its English enum value.
    var localizedPriceWithPeriod: String {
        // No `.day`: the App Store has no one-day subscription, and StoreKit no period for one.
        let period: Product.SubscriptionPeriod? = switch productDuration {
        case .year: .yearly
        case .month: .monthly
        case .week: .weekly
        case .day, nil: nil
        }
        guard let period else { return priceString }
        return String(localized: "\(priceString) / \(period.formatted(.components(style: .wide)))")
    }
}

#Preview {
    RouterView { _ in
        CustomPaywallView(
            products: AnyProduct.mocks
        )
    }
}
