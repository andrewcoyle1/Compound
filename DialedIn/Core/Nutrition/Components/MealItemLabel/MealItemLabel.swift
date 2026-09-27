//
//  MealItemLabel.swift
//  DialedIn
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
                Text(mealItem.detail(showsCalories: showCalories, showsMacros: showMacros, showsAmount: true))
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onEditPressed {
                Button {
                    onEditPressed(mealItem)
                } label: {
                    Image(systemName: Symbol.edit)
                }
                .accessibilityLabel("Edit meal item")
                .buttonStyle(.glass)
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
