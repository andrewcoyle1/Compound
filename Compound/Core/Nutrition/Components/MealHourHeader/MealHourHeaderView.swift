//
//  MealHourHeader.swift
//  Compound
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

    /// The time and the add button share one height, so the pair reads as a matched set. The time
    /// was a chip about 26 pt tall and the add a system bordered circle about 34 pt; nothing tied
    /// them together.
    @ScaledMetric(relativeTo: .caption) private var controlHeight: CGFloat = 32

    /// The widest time of day, so every hour's capsule is the same width in both 24- and 12-hour
    /// locales ("22:00", "10:00 PM"). Proportional digits made "11:00" narrower than "08:00".
    private static let widestHour = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now

    var body: some View {
        HStack {
            ZStack {
                Text(Self.widestHour, style: .time)
                    .hidden()
                Text(delegate.hour, style: .time)
            }
            .font(.label)
            .fontWeight(.semibold)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: controlHeight)
            .background(Color.tintedSurface(.secondary), in: .capsule)
            .onLongPressGesture {
                if !presenter.showAddFoodsButton {
                    presenter.onAddMealPressed(selectedTime: delegate.hour)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(delegate.hour, style: .time))
            .accessibilityAction(named: Text("Add meal")) {
                presenter.onAddMealPressed(selectedTime: delegate.hour)
            }

            if presenter.showAddFoodsButton {
                Button {
                    presenter.onAddMealPressed(selectedTime: delegate.hour)
                } label: {
                    Image(systemName: Symbol.add)
                        .font(.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Color.tintedSurface(.secondary), in: .circle)
                        .tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add meal")
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
