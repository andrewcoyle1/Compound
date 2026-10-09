//
//  ExpenditureEstimateSummary.swift
//  Compound
//
//  Today's expenditure with how sure the app is of it: the 80% interval and a confidence badge
//  once the estimate is adaptive, or a plain "Calibrating" while it is still the formula's.
//

import SwiftUI

struct ExpenditureEstimateSummary: View {
    let estimate: ExpenditureEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(Format.kcal(estimate.kcal))
                    .font(.metricLarge)
                Spacer(minLength: Spacing.xs)
                Chip(confidenceTitle, tint: confidenceTint)
            }
            Text(detail)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var confidenceTitle: String {
        switch estimate.confidence {
        case .calibrating: return String(localized: "Calibrating")
        case .low: return String(localized: "Low confidence")
        case .medium: return String(localized: "Medium confidence")
        case .high: return String(localized: "High confidence")
        }
    }

    private var confidenceTint: Color {
        switch estimate.confidence {
        case .calibrating, .low: return .secondary
        case .medium: return .warning
        case .high: return .success
        }
    }

    private var detail: String {
        if let range = estimate.likelyRange {
            let low = Format.kcal(range.lowerBound)
            let high = Format.kcal(range.upperBound)
            return String(localized: "Likely \(low) to \(high), based on what you logged.")
        }
        switch estimate.source {
        case .fixed:
            return String(localized: "Fixed at your profile's estimate.")
        case .prior, .adaptive:
            let days = ExpenditureEngine.Constants.minDays
            let weighIns = ExpenditureEngine.Constants.minWeighIns
            return String(localized: "Using the estimate from your profile until \(days) days and \(weighIns) weigh-ins are logged, with most days logged.")
        }
    }
}

#Preview {
    List {
        ExpenditureEstimateSummary(estimate: ExpenditureEstimate(
            day: Date(), kcal: 2450, source: .adaptive, isProvisional: false, trendWeightKg: 80,
            weeklyTrendChangeKg: -0.4, loggedDays: 26, weighInCount: 24, windowDays: 28, stepAdjustmentKcal: 0,
            sdKcal: 110
        ))
    }
}
