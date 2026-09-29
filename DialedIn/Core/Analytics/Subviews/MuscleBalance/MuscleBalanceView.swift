import SwiftUI

/// Weekly working sets per muscle against the recommended range, as a heatmap grid. Each tile
/// carries its status as a colour, an icon and a word, so it never rests on colour alone.
struct MuscleBalanceView: View {

    @State var presenter: MuscleBalancePresenter

    var body: some View {
        List {
            Group {
                region(header: String(localized: "Upper"), rows: presenter.upperRows)
                region(header: String(localized: "Lower"), rows: presenter.lowerRows)
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

    private func region(header: String, rows: [MuscleBalanceRow]) -> some View {
        Section {
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
            SectionHeaderView(title: header)
        } footer: {
            if header == "Lower" {
                Text("Working sets in the last 7 days. A muscle an exercise only assists counts half a set. Tap a muscle for its 12-week trend.")
                    .padding(.horizontal)
            }
        }
    }

    private func tile(_ row: MuscleBalanceRow) -> some View {
        let color = row.status.color
        let isSelected = presenter.selectedMuscle == row.muscle
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.muscle.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: row.status.systemImage)
                    .foregroundStyle(color)
            }
            Text(row.currentSets.formatted(.number.precision(.fractionLength(0...1))) + " sets")
                .font(.title3.weight(.bold))
            Text("\(row.status.label) · \(rangeText(row.range))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.18), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color, lineWidth: isSelected ? 2 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.muscle.name), \(row.currentSets.formatted(.number.precision(.fractionLength(0...1)))) sets, \(row.status.label)")
        .accessibilityValue("Recommended \(rangeText(row.range)) sets a week")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .anyButton(.press) {
            presenter.onMusclePressed(row.muscle)
        }
    }

    private func trend(_ row: MuscleBalanceRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(row.muscle.name) · last 12 weeks")
                .font(.subheadline.weight(.semibold))
            SparklineChart(
                data: presenter.sparklineData(for: row),
                configuration: SparklineConfiguration(
                    lineColor: row.status.color,
                    lineWidth: 2,
                    fillColor: row.status.color,
                    height: 60,
                    showsPoints: true
                )
            )
            Text("Target \(rangeText(row.range)) sets a week")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private func rangeText(_ range: ClosedRange<Double>) -> String {
        "\(Int(range.lowerBound))–\(Int(range.upperBound))"
    }
}

extension MuscleBalanceStatus {
    var color: Color {
        switch self {
        case .below:  return .orange
        case .within: return .green
        case .above:  return .blue
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
