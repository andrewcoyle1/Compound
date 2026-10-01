//
//  MealItemLabel.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

import SwiftUI

struct MealItemLabel: View {
    let mealItem: MealItemModel
    var showImage: Bool = true
    var showCalories: Bool = true
    var showMacros: Bool = true
    /// Nil hides the edit button.
    var onEditPressed: ((MealItemModel) -> Void)?

    var body: some View {
        HStack(spacing: Spacing.m) {
            if showImage {
                // A stand-in for the food's picture, so neutral: it is not brand emphasis.
                Image(systemName: Symbol.meal + ".circle.fill")
                    .iconSize(.medium)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(mealItem.displayName)
                    .font(.rowTitle)
                    .lineLimit(1)
                // Wraps rather than truncating, so the macros and amount always show, at any type size.
                Text(mealItem.detail(showsCalories: showCalories, showsMacros: showMacros, showsAmount: true))
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onEditPressed {
                Button {
                    onEditPressed(mealItem)
                } label: {
                    Image(systemName: Symbol.edit)
                }
                .accessibilityLabel("Edit \(mealItem.displayName)")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }
}

#Preview {
    List {
        HStack {
            ZStack {

            }
            .frame(width: 80)
            MealItemLabel(
                mealItem: .mock,
                onEditPressed: { _ in

                }
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {

            }
        }
    }
}
