//
//  BodyweightContributionBadge.swift
//  Compound
//
//  The capsule beside an exercise's name when the movement lifts bodyweight and the setting is on:
//  a ring filled to the share, today's bodyweight, and what the movement adds of it
//  ("+52.9 kg (63%)"). A tap explains effective load. The numbers are always spelled out, so the
//  ring is never the only signal.
//

import SwiftUI

struct BodyweightContributionBadge: View {

    let contribution: BodyweightContribution

    @State private var isExplaining = false
    @ScaledMetric(relativeTo: .caption) private var ringSide = ControlSize.icon

    private var share: Double { Double(contribution.percent) / 100 }

    var body: some View {
        if let bodyweightKg = contribution.bodyweightKg, let addedKg = contribution.contributionKg {
            Button {
                isExplaining = true
            } label: {
                capsule(bodyweightKg: bodyweightKg, addedKg: addedKg)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isExplaining) {
                Text("Effective load = external load + \(Format.percent(share)) of your bodyweight")
                    .font(.rowDetail)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.l)
                    .frame(idealWidth: ContentWidth.readable / 2)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bodyweight contribution")
            .accessibilityValue(spokenValue(bodyweightKg: bodyweightKg, addedKg: addedKg))
            .accessibilityHint("Explains effective load")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func capsule(bodyweightKg: Double, addedKg: Double) -> some View {
        HStack(spacing: Spacing.xs) {
            Gauge(value: share) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.success)
                // The style draws at a widget's size; scaled down to sit beside two lines of text.
                .scaleEffect(ringSide / Self.gaugeNaturalSide)
                .frame(width: ringSide, height: ringSide)

            VStack(alignment: .leading, spacing: 0) {
                Text(Format.weight(kg: bodyweightKg, unit: contribution.unit))
                    .font(.label.weight(.semibold))
                Text("\(ActiveWorkout.signedWeight(addedKg, unit: contribution.unit)) (\(Format.percent(share)))")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            // Wraps rather than truncates when the badge sits under the name at large sizes.
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.s)
        .padding(.vertical, Spacing.xxs)
        // A capsule at one line a figure; a rounded card, not a blob, once the figures wrap.
        .background(Color.tintedSurface(.success), in: .rect(cornerRadius: Radius.l, style: .continuous))
        .frame(minHeight: ControlSize.row)
        .contentShape(.rect)
    }

    /// "63 percent of 84 kilograms, 52.9 kilograms".
    private func spokenValue(bodyweightKg: Double, addedKg: Double) -> String {
        let bodyweight = ActiveWorkout.spokenWeight(kg: bodyweightKg, unit: contribution.unit)
        let added = ActiveWorkout.spokenWeight(kg: addedKg, unit: contribution.unit)
        return "\(String(localized: "\(Format.percent(share)) of \(bodyweight)")), \(added)"
    }

    /// `accessoryCircularCapacity`'s own diameter outside a widget.
    private static let gaugeNaturalSide: CGFloat = 58
}

extension EnvironmentValues {
    /// The card's rows read loads as "BW + 20 kg × 8". Set by the live tracker's card from its
    /// `BodyweightContribution`; off everywhere else.
    @Entry var showsBodyweightLoad = false
}

#Preview {
    VStack(spacing: Spacing.l) {
        BodyweightContributionBadge(contribution: BodyweightContribution(percent: 63, bodyweightKg: 83.95, unit: .kilograms))
        BodyweightContributionBadge(contribution: BodyweightContribution(percent: 100, bodyweightKg: 83.95, unit: .pounds))
    }
}
