import SwiftUI

struct HabitsDelegate {
    
}

struct HabitsView: View {
    
    @State var presenter: HabitsPresenter
    let delegate: HabitsDelegate
    
    var body: some View {
        List {
            Group {
                generalSection
                trainingSection
                nutritionSection
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
        }
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .onFirstTask {
            await presenter.onFirstTask()
        }
    }
    
    private var generalSection: some View {
        habitsSection(header: String(localized: "General")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Weigh In"),
                value: presenter.weighInCountThisWeek.formatted(),
                themeColor: Color.Metric.habits,
                data: presenter.weighInContributionData,
                action: { presenter.onWeighInPressed(themeColor: Color.Metric.habits) }
            )
        }
    }

    private var trainingSection: some View {
        habitsSection(header: String(localized: "Training")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Workouts"),
                value: presenter.workoutCountThisWeek.formatted(),
                themeColor: Color.Metric.habits,
                data: presenter.workoutContributionData,
                action: { presenter.onWorkoutsPressed(themeColor: Color.Metric.habits) }
            )
        }
    }

    private var nutritionSection: some View {
        habitsSection(header: String(localized: "Nutrition")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Food Logging"),
                value: "\(presenter.foodLoggingCountThisWeek)/7",
                themeColor: Color.Metric.habits,
                data: presenter.foodLoggingContributionData,
                action: { presenter.onFoodLoggingPressed(themeColor: Color.Metric.habits) }
            )
        }
    }

    /// Every habit is drawn in `Color.Metric.habits`: they are one metric, consistency, shown three
    /// ways, and the per-habit greens and oranges clashed with the metrics of the same name.
    private func habitsSection<Content: View>(
        header: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            AnalyticsCardGrid(content: content)
        } header: {
            SectionHeaderView(title: header)
        }
    }
}

extension CoreBuilder {
    
    func habitsView(router: AnyRouter, delegate: HabitsDelegate) -> some View {
        HabitsView(
            presenter: HabitsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showHabitsView(delegate: HabitsDelegate) {
        router.showScreen(.push) { router in
            builder.habitsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = HabitsDelegate()
    
    return RouterView { router in
        builder.habitsView(router: router, delegate: delegate)
    }
    
}
