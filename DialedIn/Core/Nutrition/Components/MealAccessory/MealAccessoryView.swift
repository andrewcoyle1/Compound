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
        
    private var workoutDescriptionSection: some View {
        HStack {
            VStack(alignment: .leading) {
                workoutName
                timeSection(draftMeal: delegate.draftMeal)
            }
            Spacer()
            exerciseImagesSection
        }
    }

    private var exerciseImagesSection: some View {
        HStack(spacing: -10) {
            ForEach(presenter.draftMeal.items.prefix(5)) { draftMeal in
                mealItemCircle(draftMeal: draftMeal)
            }
        }
    }

    @ViewBuilder
    private func mealItemCircle(draftMeal: MealItemModel) -> some View {
        let isCompleted = !draftMeal.amount.isZero
        ZStack {
            Circle()
                .fill(.surface)

            ImageLoaderView(
                urlString: "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
            .grayscale(isCompleted ? 1 : 0)

            if isCompleted {
                // A scrim over the item's picture, so the check reads on any image.
                Circle()
                    .fill(.black.opacity(0.4))
                Image(systemName: "checkmark")
                    .font(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: ControlSize.thumbnail, height: ControlSize.thumbnail)
        .overlay(Circle().stroke(.canvas, lineWidth: Spacing.xxs))
    }
    
    private var workoutName: some View {
        Text(delegate.draftMeal.date.formatted(date: .omitted, time: .shortened))
            .font(.rowDetail)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    private func timeSection(draftMeal: MealLogModel) -> some View {
        // Elapsed time
        HStack(spacing: Spacing.xs) {
            Text("Elapsed: ")
            Text(presenter.draftMeal.date, style: .timer)
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .font(.rowDetail)
        .multilineTextAlignment(.leading)
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
