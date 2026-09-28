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
    }
        
    /// Says what it is, an unlogged meal, and what is on it. It used to reuse the workout
    /// accessory: an "Elapsed" timer and a checkmark over every thumbnail.
    private var workoutDescriptionSection: some View {
        VStack(alignment: .leading) {
            Text("Unlogged meal")
                .font(.rowDetail)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text("^[\(presenter.draftMeal.items.count) item](inflect: true) · \(Format.kcal(presenter.draftMeal.totalCalories))")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
