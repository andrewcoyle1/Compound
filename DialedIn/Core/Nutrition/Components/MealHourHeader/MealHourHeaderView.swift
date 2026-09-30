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
                .chipStyle(tint: .secondary, filled: false)
                .onLongPressGesture {
                    if !presenter.showAddFoodsButton {
                        presenter.onAddMealPressed(selectedTime: delegate.hour)
                    }
                }
                .accessibilityAction(named: Text("Add meal")) {
                    presenter.onAddMealPressed(selectedTime: delegate.hour)
                }

            if presenter.showAddFoodsButton {
                Button {
                    presenter.onAddMealPressed(selectedTime: delegate.hour)
                } label: {
                    Image(systemName: Symbol.add)
                }
                .accessibilityLabel("Add meal")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }

            Spacer()

            if !delegate.meals.isEmpty && presenter.showHourlyMacroTotals {
                HStack(spacing: Spacing.l) {
                    ForEach(Macro.allCases, id: \.self) { macro in
                        Stat(
                            value: "\(presenter.total(of: macro, in: delegate.meals))",
                            label: macro.title,
                            size: .small,
                            alignment: .center
                        )
                    }
                }
            }
        }
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
