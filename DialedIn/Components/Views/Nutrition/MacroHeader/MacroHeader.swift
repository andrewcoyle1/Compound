//
//  MacroHeader.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import SwiftUI

struct MacroHeader: View {
    
    var dailyTotals: DailyMacroTarget
    var dailyTarget: DailyMacroTarget
    
    var showCaloriesRing: Bool = true
    var showProteinRing: Bool = true
    var showFatRing: Bool = true
    var showCarbsRing: Bool = true

    /// Whether the remaining page may go below zero.
    ///
    /// Off — the default, and what every user saw before this was read — a target already met
    /// reads "0 left". On, the figure keeps counting past zero, so eating 20g of protein over
    /// target reads "-20 left" and the overage is visible rather than rounded away.
    var showOverages: Bool = false

    /// Which page the header opens on. The other is always a swipe away, so this is a starting
    /// point rather than a mode.
    var remainingMode: Bool = false

    @State private var page: Page?

    /// Consumed against target, then how much of it is left.
    private enum Page: Int, CaseIterable, Identifiable {
        case consumed
        case remaining

        var id: Int { rawValue }
    }

    var body: some View {
        VStack(spacing: Self.dotSpacing) {
            pages
            pageIndicator
        }
        .padding(.bottom, 6)
        .onAppear {
            // Set here rather than as the property's initial value, so there is a row to scroll to
            // by the time the position is applied.
            page = remainingMode ? .remaining : .consumed
        }
    }

    /// A paging `ScrollView` rather than a `TabView`: `.tabViewStyle(.page)` reserves room for its
    /// own dots *inside* the content, which is what was sitting over the bars. Here the indicator
    /// is a sibling, so the header is only as tall as its content plus 9pt.
    private var pages: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Page.allCases) { page in
                    macroRow(for: page)
                        .containerRelativeFrame(.horizontal)
                        .id(page)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(Page.allCases) { dot in
                Circle()
                    .fill(dot == page ? Color.primary.opacity(0.6) : Color.secondary.opacity(0.25))
                    .frame(width: Self.dotSize, height: Self.dotSize)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: page)
        .accessibilityHidden(true)
    }

    private func macroRow(for page: Page) -> some View {
        HStack {
            ForEach(Macro.allCases, id: \.self) { macro in
                if shouldShow(macro) {
                    valuesForMacro(macro: macro, page: page)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .tappableBackground()
    }

    @ViewBuilder
    private func valuesForMacro(macro: Macro, page: Page) -> some View {
        switch macro {
        case .cals:
            macroBar(macro: .cals, total: dailyTotals.calories, target: dailyTarget.calories, page: page) {
                Image(systemName: "flame")
            }
        case .fat:
            macroBar(macro: .fat, total: dailyTotals.fatGrams, target: dailyTarget.fatGrams, page: page) {
                Text("F").bold()
            }
        case .protein:
            macroBar(macro: .protein, total: dailyTotals.proteinGrams, target: dailyTarget.proteinGrams, page: page) {
                Text("P").bold()
            }
        case .carbs:
            macroBar(macro: .carbs, total: dailyTotals.carbGrams, target: dailyTarget.carbGrams, page: page) {
                Text("C").bold()
            }
        }
    }

    private func macroBar(
        macro: Macro,
        total: Double,
        target: Double,
        page: Page,
        icon: () -> some View
    ) -> some View {
        let remaining = Self.remaining(total: total, target: target, showOverages: showOverages)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                icon()
                Text(page == .consumed ? String(localized: "\(String(describing: Int(total))) / \(String(describing: Int(target)))") : String(localized: "\(String(describing: Int(remaining))) left"))
            }
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            // The bar drains on the remaining page, so it agrees with the figure above it.
            ProgressView(value: progress(page == .consumed ? total : remaining, of: target))
                .tint(macro.colour)
        }
    }

    /// How much of `target` is left, as the remaining page prints it.
    ///
    /// Clamped at zero unless the user asked for overages, in which case it keeps going: a target
    /// exceeded by 20 reads "-20 left" rather than "0 left", which says nothing about how far past
    /// it they are. Lifted out of `macroBar` so it can be read without a view.
    static func remaining(total: Double, target: Double, showOverages: Bool) -> Double {
        showOverages ? target - total : max(target - total, 0)
    }

    /// A fraction in 0...1, because `ProgressView(value:total:)` warns at runtime for anything
    /// outside `0...total` — which covers both eating past a target and a target of zero, as
    /// happens for a macro the diet plan does not set.
    private func progress(_ value: Double, of target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    private func shouldShow(_ macro: Macro) -> Bool {
        switch macro {
        case .cals: return showCaloriesRing
        case .protein: return showProteinRing
        case .fat: return showFatRing
        case .carbs: return showCarbsRing
        }
    }

    private static let dotSize: CGFloat = 5
    private static let dotSpacing: CGFloat = 4
}

#Preview {
    
    let totals = DailyMacroTarget(
        calories: 2000,
        proteinGrams: 140,
        carbGrams: 200,
        fatGrams: 50
    )
    let targets = DailyMacroTarget(
        calories: 2145,
        proteinGrams: 150,
        carbGrams: 242,
        fatGrams: 64
    )
    
    List {
        Text("Hello, World!")
    }
    .safeAreaInset(edge: .top) {
        MacroHeader(
            dailyTotals: totals,
            dailyTarget: targets
        )
        .background(.bar)
    }
}

#Preview("Over target, opens on remaining") {
    // Protein and fat are past their targets — the case that tripped ProgressView's out-of-bounds
    // warning. Both should read "0 left" with an empty bar.
    let totals = DailyMacroTarget(
        calories: 2400,
        proteinGrams: 175,
        carbGrams: 200,
        fatGrams: 80
    )

    List {
        Text("Hello, World!")
    }
    .safeAreaInset(edge: .top) {
        MacroHeader(
            dailyTotals: totals,
            dailyTarget: .mock,
            remainingMode: true
        )
        .background(.bar)
    }
}

#Preview("Over target, showing overages") {
    // The same numbers as above with the setting on: protein and fat read past zero rather than
    // stopping at it.
    let totals = DailyMacroTarget(
        calories: 2400,
        proteinGrams: 175,
        carbGrams: 200,
        fatGrams: 80
    )

    List {
        Text("Hello, World!")
    }
    .safeAreaInset(edge: .top) {
        MacroHeader(
            dailyTotals: totals,
            dailyTarget: .mock,
            showOverages: true,
            remainingMode: true
        )
        .background(.bar)
    }
}

#Preview("No targets set") {
    // Every target is zero, so nothing should fill and nothing should warn.
    let empty = DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)

    List {
        Text("Hello, World!")
    }
    .safeAreaInset(edge: .top) {
        MacroHeader(
            dailyTotals: empty,
            dailyTarget: empty
        )
        .background(.bar)
    }
}
