import SwiftUI

struct ExerciseAnalyticsDelegate {
    
}

struct ExerciseAnalyticsView: View {

    @State var presenter: ExerciseAnalyticsPresenter
    let delegate: ExerciseAnalyticsDelegate

    var body: some View {
        List {
            Section {
                let exerciseColor = Color.cyan
                AnalyticsCardGrid {
                    if presenter.exerciseCards.isEmpty {
                        // The header used to stand over an empty grid on a fresh account.
                        AnalyticsEmptyCard(message: String(localized: "Log a workout to track your estimated one-rep max."))
                    } else {
                        ForEach(presenter.exerciseCards) { item in
                            SparklineAnalyticsCard(
                                title: item.name,
                                subtitle: String(localized: "Last 7 Workouts"),
                                value: item.latest1RM > 0 ? item.latest1RM.formatted(.number.precision(.fractionLength(1))) : "--",
                                unit: item.unitText,
                                themeColor: exerciseColor,
                                data: item.sparklineData,
                                action: {
                                    presenter.onExercisePressed(
                                        templateId: item.templateId,
                                        name: item.name,
                                        themeColor: exerciseColor
                                    )
                                }
                            )
                        }
                    }
                }
            } header: {
                SectionHeaderView(title: String(localized: "Exercises"))
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
        }
        .onFirstTask {
            await presenter.loadData()
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }
}

extension CoreBuilder {
    
    func exerciseAnalyticsView(router: AnyRouter, delegate: ExerciseAnalyticsDelegate) -> some View {
        ExerciseAnalyticsView(
            presenter: ExerciseAnalyticsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showExerciseAnalyticsView(delegate: ExerciseAnalyticsDelegate) {
        router.showScreen(.sheet) { router in
            builder.exerciseAnalyticsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ExerciseAnalyticsDelegate()
    
    return RouterView { router in
        builder.exerciseAnalyticsView(router: router, delegate: delegate)
    }
    
}
