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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }
    
    private var generalSection: some View {
        habitsSection(header: String(localized: "General")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Weigh In"),
                value: "\(presenter.weighInCountThisWeek)",
                themeColor: .green,
                data: presenter.weighInContributionData,
                action: { presenter.onWeighInPressed(themeColor: .green) }
            )
        }
    }

    private var trainingSection: some View {
        habitsSection(header: String(localized: "Training")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Workouts"),
                value: "\(presenter.workoutCountThisWeek)",
                themeColor: .orange,
                data: presenter.workoutContributionData,
                action: { presenter.onWorkoutsPressed(themeColor: .orange) }
            )
        }
    }

    private var nutritionSection: some View {
        habitsSection(header: String(localized: "Nutrition")) {
            ConsistencyAnalyticsCard(
                title: String(localized: "Food Logging"),
                value: "\(presenter.foodLoggingCountThisWeek)/7",
                themeColor: .teal,
                data: presenter.foodLoggingContributionData,
                action: { presenter.onFoodLoggingPressed(themeColor: .teal) }
            )
        }
    }

    /// Food Logging was orange, the same colour as Workouts directly above it, so the two habits
    /// read as one. Each habit now has its own colour, and each section the same shape.
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
        router.showScreen(.sheet) { router in
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
