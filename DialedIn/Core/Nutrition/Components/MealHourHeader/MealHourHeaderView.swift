//
//  MealHourHeader.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/03/2026.
//

import SwiftUI

struct MealHourHeaderDelegate {
    let hour: Date
    var meals: [MealLogModel]
}

struct MealHourHeaderView: View {
    
    @State var presenter: MealHourHeaderPresenter
    let delegate: MealHourHeaderDelegate
    
    var body: some View {
        HStack {
            Text(delegate.hour, style: .time)
                .lineLimit(1)
                .padding(6)
                .padding(.horizontal, 6)
//                .frame(width: 80)
                .background(.secondary.opacity(0.2), in: .capsule)
                .onLongPressGesture {
                    if !presenter.showAddFoodsButton {
                        presenter.onAddMealPressed(selectedTime: delegate.hour)
                    }
                }
            
            if presenter.showAddFoodsButton {
                Button {
                    presenter.onAddMealPressed(selectedTime: delegate.hour)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add meal")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            
            Spacer()
            
            if !delegate.meals.isEmpty && presenter.showHourlyMacroTotals {
                HStack(spacing: 16) {
                    ForEach(Macro.allCases, id: \.self) { macro in
                        var value: Int {
                            switch macro {
                            case .cals:
                                return Int(
                                    delegate.meals
                                        .compactMap { $0.totalCalories }
                                        .reduce(0.0, +)
                                )
                                
                            case .carbs:
                                return Int(
                                    delegate.meals
                                        .compactMap { $0.totalCarbGrams }
                                        .reduce(0.0, +)
                                )
                            case .fat:
                                return Int(
                                    delegate.meals
                                        .compactMap { $0.totalFatGrams }
                                        .reduce(0.0, +)
                                )
                                
                            case .protein:
                                return Int(
                                    delegate.meals
                                        .compactMap { $0.totalProteinGrams }
                                        .reduce(0.0, +)
                                )
                            }
                        }
                        MacroLabel(
                            title: macro.title,
                            value: value
                        )
                    }
                }
            }
        }
        .font(.caption)
        .removeListRowFormatting()

    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = MealHourHeaderDelegate(hour: .now, meals: MealLogModel.mocks)
    
    RouterView { router in
        List {
            Section {
                builder.mealHourHeader(router: router, delegate: delegate)
            }
            .listSectionMargins(.all, 0)
            .padding(.horizontal)
            .listRowSeparator(.hidden)
        }
        .navigationTitle("Meal Hour Header View")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension CoreBuilder {
    func mealHourHeader(router: AnyRouter, delegate: MealHourHeaderDelegate) -> some View {
        MealHourHeaderView(
            presenter: MealHourHeaderPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}
