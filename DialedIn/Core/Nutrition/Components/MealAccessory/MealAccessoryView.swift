//
//  MealAccessoryView.swift
//  DialedIn
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

    let delegate: MealAccessoryDelegate

    var body: some View {
        Button {
            presenter.reopenMealLog()
        } label: {
            workoutDescriptionSection
                .frame(maxWidth: .infinity)
                .padding()
                .tappableBackground()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var isInline: Bool {
        placement == .inline
    }

    /// "Continue draft meal, 2 items" — one label for the whole button.
    private var accessibilityLabel: String {
        let count = presenter.draftMeal.items.count
        let items = count == 1 ? String(localized: "1 item") : String(localized: "\(count) items")
        return String(localized: "Continue draft meal, \(items)")
    }

    private var itemsLine: Text {
        Text("^[\(presenter.draftMeal.items.count) item](inflect: true) · \(Format.kcal(presenter.draftMeal.totalCalories))")
            .foregroundStyle(.secondary)
    }

    /// Says what it is, an unlogged meal, and what is on it. It used to reuse the workout
    /// accessory: an "Elapsed" timer and a checkmark over every thumbnail.
    @ViewBuilder
    private var workoutDescriptionSection: some View {
        if isInline {
            // No room to spare inline: one line.
            HStack {
                (Text("Unlogged meal").fontWeight(.semibold) + Text(" · ") + itemsLine)
                    .font(.rowDetail)
                    .lineLimit(1)
                Spacer()
            }
        } else {
            VStack(alignment: .leading) {
                Text("Unlogged meal")
                    .font(.rowDetail)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                itemsLine
                    .font(.rowDetail)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
