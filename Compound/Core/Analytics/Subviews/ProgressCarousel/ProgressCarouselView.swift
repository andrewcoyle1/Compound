//
//  ProgressCarouselView.swift
//  Compound
//

import SwiftUI

/// The header of the Progress tab: the weekly target grid, then today's nutrition, energy
/// balance, this week's training and recent records, a page each.
struct ProgressCarouselView<WeeklyNutrition: View>: View {
    @State var presenter: ProgressCarouselPresenter
    @ViewBuilder var weeklyNutrition: () -> WeeklyNutrition

    @State private var page: Page? = .weeklyNutrition

    private enum Page: Int, CaseIterable, Identifiable {
        case weeklyNutrition
        case dailyNutrition
        case energyBalance
        case weeklyWorkouts
        case recentRecords

        var id: Int { rawValue }
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            // A paging `ScrollView` with the dots as a sibling, as `MacroHeader` does: a page-style
            // `TabView` draws its dots over the content.
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Page.allCases) { page in
                        content(for: page)
                            .frame(maxWidth: ContentWidth.readable, maxHeight: .infinity, alignment: .top)
                            .padding(.horizontal, Spacing.l)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                // Every page as tall as the tallest, so each one's toggle sits on the same line.
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)

            pageIndicator
        }
        .task {
            await presenter.load()
        }
    }

    @ViewBuilder
    private func content(for page: Page) -> some View {
        switch page {
        case .weeklyNutrition: weeklyNutrition()
        case .dailyNutrition: DailyNutritionCard(presenter: presenter)
        case .energyBalance: EnergyBalanceCard(presenter: presenter)
        case .weeklyWorkouts: WeeklyWorkoutsCard(presenter: presenter)
        case .recentRecords: RecentRecordsCard(presenter: presenter)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Page.allCases) { dot in
                Circle()
                    .fill(dot == page ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
        .reducedMotionAnimation(.quick, value: page)
        .accessibilityHidden(true)
    }
}

/// One page after the weekly grid: its title, the figures, and the toggle at the foot. The figures
/// fill whatever height the tallest page sets, so each card lays its rows out over the whole page
/// rather than leaving a gap above the toggle.
struct CarouselPage<Content: View, Toggle: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var toggle: () -> Toggle

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeaderView(title: title)
                .carouselTitleStyle()
            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Figures count up and down when a toggle changes what they show.
            .contentTransition(.numericText())
            toggle()
        }
    }
}

extension View {
    /// A carousel page's title, matching the list's section headers below the carousel.
    func carouselTitleStyle() -> some View {
        font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// The segmented control at the foot of each page.
struct CarouselToggle<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .frame(maxWidth: .infinity)
    }
}

extension CoreBuilder {
    func progressCarouselView(router: AnyRouter) -> some View {
        ProgressCarouselView(presenter: ProgressCarouselPresenter(interactor: interactor)) {
            self.nutritionTargetChartView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        List {
            builder.progressCarouselView(router: router)
                .listRowInsets(EdgeInsets())
        }
    }
}
