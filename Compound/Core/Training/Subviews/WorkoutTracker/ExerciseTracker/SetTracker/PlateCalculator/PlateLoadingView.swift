//
//  PlateLoadingView.swift
//  Compound
//
//  How a weight goes on the bar: one sleeve drawn with its plates, the plates counted, and the
//  sum that makes the total. Shown above the weight keyboard and at the top of the plate
//  calculator.
//

import SwiftUI

/// The plates on one sleeve and the sum they make, as words. Pure, so it can be tested.
struct PlateLoading: Equatable {
    /// One sleeve's plates, heaviest first.
    let perSide: [Double]
    let base: Double
    let sleeves: Int
    let unit: ExerciseWeightUnit

    var total: Double { base + perSide.reduce(0, +) * Double(sleeves) }

    /// "1 × 25 · 2 × 10", heaviest first.
    var counts: String {
        var groups: [(weight: Double, count: Int)] = []
        for plate in perSide {
            if let last = groups.last, abs(last.weight - plate) < 0.001 {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((plate, 1))
            }
        }
        return groups.map { "\($0.count) × \(WeightStepper.format($0.weight))" }.joined(separator: " · ")
    }

    /// "25 kg on each side + 20 kg bar = 70 kg", "25 kg of plates + 18 kg base = 43 kg" on a
    /// single-sleeve machine, or "Empty bar = 20 kg".
    var equation: String {
        let base = amount(base)
        let total = amount(total)
        guard !perSide.isEmpty else { return String(localized: "Empty bar = \(total)") }
        let plates = amount(perSide.reduce(0, +))
        return sleeves == 1
            ? String(localized: "\(plates) of plates + \(base) base = \(total)")
            : String(localized: "\(plates) on each side + \(base) bar = \(total)")
    }

    private func amount(_ value: Double) -> String {
        "\(WeightStepper.format(value)) \(unit.abbreviation)"
    }
}

struct PlateLoadingView: View {

    let loading: PlateLoading
    /// The gym's plates, for their colours.
    let plates: [Plate]

    @ScaledMetric(relativeTo: .subheadline) private var diagramWidth: CGFloat = 88
    @ScaledMetric(relativeTo: .subheadline) private var diagramHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: Spacing.m) {
            BarSleeveDiagram(perSide: loading.perSide, plates: plates)
                .frame(width: diagramWidth, height: diagramHeight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if !loading.perSide.isEmpty {
                    Text(loading.counts)
                        .font(.rowTitle.monospacedDigit())
                }
                Text(loading.equation)
                    .font(.rowDetail.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One sleeve of a bar, collar on the left, plates outward from it: taller for heavier, in the
/// gym's colour for that plate.
private struct BarSleeveDiagram: View {

    let perSide: [Double]
    let plates: [Plate]

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let shaft = CGRect(x: 0, y: midY - 2, width: size.width, height: 4)
            context.fill(Path(shaft), with: .style(.secondary))
            let collar = CGRect(x: size.width * 0.12, y: midY - size.height * 0.18, width: 4, height: size.height * 0.36)
            context.fill(Path(collar), with: .style(.secondary))

            let heaviest = perSide.max() ?? 1
            let plateWidth = max(3, min(8, (size.width * 0.8) / CGFloat(max(perSide.count, 1)) - 1))
            var left = collar.maxX + 1
            for weight in perSide {
                let height = size.height * (0.4 + 0.6 * CGFloat(weight / heaviest))
                let rect = CGRect(x: left, y: midY - height / 2, width: plateWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(colour(for: weight)))
                left += plateWidth + 1
            }
        }
    }

    private func colour(for weight: Double) -> Color {
        guard let hex = plates.first(where: { abs($0.weight - weight) < 0.001 })?.colour, !hex.isEmpty else {
            return .primary
        }
        return Color(hex: hex)
    }
}

#Preview {
    PlateLoadingView(
        loading: PlateLoading(perSide: [25, 10, 2.5], base: 20, sleeves: 2, unit: .kilograms),
        plates: [Plate(weight: 25, colour: "#E53935"), Plate(weight: 10, colour: "#43A047"), Plate(weight: 2.5)]
    )
    .padding()
}
