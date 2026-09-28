import SwiftUI

/// Weekly working sets per muscle against the recommended range, as a heatmap grid. Each tile
/// carries its status as a colour, an icon and a word, so it never rests on colour alone.
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
        .onFirstAppear {
            presenter.loadData()
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
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
                Text("Working sets in the last 7 days. A muscle an exercise only assists counts half a set. Tap a muscle for its 12-week trend.")
                    .padding(.horizontal)
            }
        }
    }

    private func tile(_ row: MuscleBalanceRow) -> some View {
        let color = row.status.color
        let isSelected = presenter.selectedMuscle == row.muscle
        let sets = row.currentSets.formatted(.number.precision(.fractionLength(0...1)))
        return Stat.tile(
            value: String(localized: "\(sets) sets"),
            label: "\(row.muscle.name) · \(row.status.label) \(rangeText(row.range))",
            systemImage: row.status.systemImage,
            tint: color
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(color, lineWidth: isSelected ? 2 : 0)
        }
        // The reference pattern: one element, the muscle and its status first, the target after.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.muscle.name), \(sets) sets, \(row.status.label)")
        .accessibilityValue("Recommended \(rangeText(row.range)) sets a week")
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
                configuration: SparklineConfiguration(
                    lineColor: row.status.color,
                    lineWidth: 2,
                    fillColor: row.status.color,
                    height: ChartHeight.compact / 2,
                    showsPoints: true
                )
            )
            Text("Target \(rangeText(row.range)) sets a week")
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
        // Under and over are both "attention": the symbol and the word tell them apart.
        case .below:  return .warning
        case .within: return .success
        case .above:  return .warning
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
        router.showScreen(.sheet) { router in
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
