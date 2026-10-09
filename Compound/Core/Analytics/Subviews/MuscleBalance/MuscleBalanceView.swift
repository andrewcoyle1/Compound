import SwiftUI

/// Weekly hard sets per muscle against the volume tiers, as a heatmap grid. Each tile carries its
/// tier as a colour, an icon and a word, so it never rests on colour alone.
struct MuscleBalanceView: View {

    @State var presenter: MuscleBalancePresenter

    var body: some View {
        List {
            Group {
                ForEach(presenter.regions, id: \.self) { region in
                    section(region)
                }
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
        }
        .navigationTitle("Muscle Balance")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MethodInfoButton(.weeklyVolumeTiers)
            }
        }
        .onFirstAppear {
            presenter.loadData()
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func section(_ region: BodyRegion) -> some View {
        let rows = presenter.rows(for: region)
        return Section {
            AnalyticsCardGrid {
                ForEach(rows) { row in
                    tile(row)
                }
            }
            if let selected = presenter.selectedRow, rows.contains(selected) {
                trend(selected)
                    .padding(.horizontal)
                    .removeListRowFormatting()
            }
        } header: {
            SectionHeaderView(title: presenter.header(for: region))
        } footer: {
            if presenter.showsFooter(for: region) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("Hard sets in the last 7 days. A muscle an exercise only assists counts half a set. Tap a muscle for its 12-week trend.")
                    MethodInfoButton(.weeklyHardSets)
                }
                .padding(.horizontal)
            }
        }
    }

    private func tile(_ row: MuscleBalanceRow) -> some View {
        let color = row.status.color
        let isSelected = presenter.selectedMuscle == row.muscle
        let sets = Format.sets(row.currentSets)
        return Stat.tile(
            value: sets,
            label: "\(row.muscle.name) · \(row.status.label)",
            systemImage: row.status.systemImage,
            tint: color
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(color, lineWidth: isSelected ? 2 : 0)
        }
        // The reference pattern: one element, the muscle and its status first, the target after.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.muscle.name), \(sets), \(row.status.label)")
        .accessibilityValue("Productive range \(rangeText(row.range)) sets a week")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .anyButton(.press) {
            presenter.onMusclePressed(row.muscle)
        }
    }

    private func trend(_ row: MuscleBalanceRow) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("\(row.muscle.name) · last 12 weeks")
                .font(.sectionTitle)
            SparklineChart(
                data: presenter.sparklineData(for: row),
                color: row.status.color,
                height: ChartHeight.compact / 2
            )
            Text(row.status.explanation)
                .font(.label)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.m)
        .cardSurface(.tile)
    }

    private func rangeText(_ range: ClosedRange<Double>) -> String {
        Format.repRange(Int(range.lowerBound), Int(range.upperBound))
    }
}

extension MuscleBalanceStatus {
    var color: Color {
        switch self {
        // Below maintenance and high are both "attention": the symbol and the word tell them apart.
        case .belowMaintenance: return .warning
        case .maintaining:      return .secondary
        case .productive:       return .success
        case .high:             return .warning
        }
    }
}

extension CoreBuilder {

    func muscleBalanceView(router: AnyRouter) -> some View {
        MuscleBalanceView(
            presenter: MuscleBalancePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {

    func showMuscleBalanceView() {
        router.showScreen(.push) { router in
            builder.muscleBalanceView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.muscleBalanceView(router: router)
    }
}
