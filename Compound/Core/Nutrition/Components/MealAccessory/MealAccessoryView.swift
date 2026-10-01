//
//  MealAccessoryView.swift
//  Compound
//
//  Created by Andrew Coyle on 17/10/2025.
//

import SwiftUI

struct MealAccessoryDelegate {
    var draftMeal: MealLogModel
}

struct MealAccessoryView: View {

    @State var presenter: MealAccessoryPresenter
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let delegate: MealAccessoryDelegate

    var body: some View {
        Button {
            presenter.reopenMealLog()
        } label: {
            summary
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .tappableBackground()
        }
        .buttonStyle(.plain)
        // The accessory is a fixed-height capsule: past AX1 even one line no longer fits in it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// Inline beside the minimised tab bar, or text too large for two lines in the fixed-height
    /// capsule (two lines overflowed it from XXL up).
    private var isInline: Bool {
        placement == .inline || dynamicTypeSize > .xLarge
    }

    /// "Continue draft meal, 2 items" — one label for the whole button.
    private var accessibilityLabel: String {
        String(localized: "Continue draft meal, \(presenter.draftMeal.items.count) items")
    }

    private var itemCountLine: Text {
        Text("^[\(presenter.draftMeal.items.count) item](inflect: true)")
            .foregroundStyle(.secondary)
    }

    private var itemsLine: Text {
        Text("^[\(presenter.draftMeal.items.count) item](inflect: true) · \(Format.kcal(presenter.draftMeal.totalCalories))")
            .foregroundStyle(.secondary)
    }

    /// The same shape as the workout accessory: a leading symbol, title over subtitle.
    private var summary: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: Symbol.meal)
                .font(.label.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(Color.tintedSurface(.accentColor), in: .circle)
                .accessibilityHidden(true)
            if isInline {
                // Calories dropped inline: there is room for the title and the count, not both.
                Text("\(Text("Unlogged meal").fontWeight(.semibold)) · \(itemCountLine)")
                    .font(.rowDetail)
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Unlogged meal")
                        .font(.rowDetail)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    itemsLine
                        .font(.rowDetail)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.s)
        }
    }
}

extension CoreBuilder {
    func mealAccessoryView(router: AnyRouter, delegate: MealAccessoryDelegate) -> some View {
        return MealAccessoryView(
            presenter: MealAccessoryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView(addNavigationStack: false) { router in
        TabView {
            Tab {
                Text("Tab")
            } label: {
                Text("Tab")
            }
        }
        .tabViewBottomAccessory {
            builder.mealAccessoryView(
                router: router, 
                delegate: MealAccessoryDelegate(draftMeal: .mock)
            )
        }
    }
}
