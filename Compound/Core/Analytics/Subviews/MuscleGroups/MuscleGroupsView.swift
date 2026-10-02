import SwiftUI

struct MuscleGroupsDelegate {
    
}

struct MuscleGroupsView: View {
    
    @State var presenter: MuscleGroupsPresenter
    let delegate: MuscleGroupsDelegate
    
    private enum BodyRegion {
        case upper, lower

        var header: String {
            switch self {
            case .upper: return String(localized: "Upper")
            case .lower: return String(localized: "Lower")
            }
        }

        /// Each region needs its own literal, not a lowercased title, so it can be translated.
        var emptyMessage: String {
            switch self {
            case .upper: return String(localized: "No upper body muscles to show yet.")
            case .lower: return String(localized: "No lower body muscles to show yet.")
            }
        }
    }

    var body: some View {
        List {
            Group {
                muscleSection(region: .upper, muscles: presenter.upperMuscles)
                muscleSection(region: .lower, muscles: presenter.lowerMuscles)
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
        }
        .onFirstAppear {
            presenter.loadData()
        }
        .navigationTitle("Muscle Groups")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Muscle Balance", systemImage: "square.grid.3x3.fill") {
                    presenter.onMuscleBalancePressed()
                }
            }
        }
    }
    
    @ViewBuilder
    private func muscleSection(region: BodyRegion, muscles: [Muscles]) -> some View {
        Section {
            AnalyticsCardGrid {
                if muscles.isEmpty {
                    AnalyticsEmptyCard(message: region.emptyMessage)
                } else {
                    ForEach(muscles, id: \.self) { muscle in
                        muscleCard(muscle: muscle)
                    }
                }
            }
        } header: {
            SectionHeaderView(title: region.header)
        }
    }

    private func muscleCard(muscle: Muscles) -> some View {
        let muscleGroupColor = Color.Metric.muscleGroups
        let data = presenter.setsData(for: muscle)
        return AnalyticsCard(
            title: muscle.name,
            subtitle: String(localized: "Last 7 Days"),
            value: data.total.formatted(.number.precision(.fractionLength(0...1))),
            unit: String(localized: "sets"),
            themeColor: muscleGroupColor,
            chartConfiguration: .compact
        ) {
            SetsBarChart(data: data.last7Days, color: muscleGroupColor)
        }
        .analyticsCardButton {
            presenter.onMusclePressed(muscle: muscle, themeColor: muscleGroupColor)
        }
    }
}

extension CoreBuilder {
    
    func muscleGroupsView(router: AnyRouter, delegate: MuscleGroupsDelegate) -> some View {
        MuscleGroupsView(
            presenter: MuscleGroupsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showMuscleGroupsView(delegate: MuscleGroupsDelegate) {
        router.showScreen(.push) { router in
            builder.muscleGroupsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = MuscleGroupsDelegate()
    
    return RouterView { router in
        builder.muscleGroupsView(router: router, delegate: delegate)
    }
    
}
