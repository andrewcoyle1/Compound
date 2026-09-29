import SwiftUI

struct MuscleGroupsDelegate {
    
}

struct MuscleGroupsView: View {
    
    @State var presenter: MuscleGroupsPresenter
    let delegate: MuscleGroupsDelegate
    
    var body: some View {
        List {
            Group {
                muscleSection(header: String(localized: "Upper"), muscles: presenter.upperMuscles)
                muscleSection(header: String(localized: "Lower"), muscles: presenter.lowerMuscles)
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
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Muscle Balance", systemImage: "square.grid.3x3.fill") {
                    presenter.onMuscleBalancePressed()
                }
            }
        }
    }
    
    @ViewBuilder
    private func muscleSection(header: String, muscles: [Muscles]) -> some View {
        Section {
            AnalyticsCardGrid {
                if muscles.isEmpty {
                    AnalyticsEmptyCard(message: String(localized: "No \(header.lowercased()) body muscles to show yet."))
                } else {
                    ForEach(muscles, id: \.self) { muscle in
                        muscleCard(muscle: muscle)
                    }
                }
            }
        } header: {
            SectionHeaderView(title: header)
        }
    }

    private func muscleCard(muscle: Muscles) -> some View {
        let muscleGroupColor = Color.blue
        let data = presenter.setsData(for: muscle)
        return AnalyticsCard(
            title: muscle.name,
            subtitle: "Last 7 Days",
            subsubtitle: data.total.formatted(.number.precision(.fractionLength(0...1))),
            subsubsubtitle: "sets",
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
        router.showScreen(.sheet) { router in
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
