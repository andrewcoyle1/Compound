//
//  VolumeRecommendationSection.swift
//  Compound
//
//  The muscle detail screen's suggestion for the next two to three weeks' sets, with the figures
//  it rests on. A suggestion only: nothing in the user's templates changes.
//

import SwiftUI

struct VolumeRecommendationSection: View {

    let result: VolumeRecommendation.Result

    var body: some View {
        Section {
            ListRow(title: headline, subtitle: detail, systemImage: systemImage, tint: tint)
            LabeledContent(String(localized: "Your recent weeks"), value: Format.sets(result.baselineSets))
            if let suggested = result.suggestedSets {
                LabeledContent(String(localized: "Suggested"), value: suggestedText(suggested))
            }
            if let trend = result.trendPercentPerWeek {
                LabeledContent(String(localized: "Strength trend"), value: trendText(trend))
            }
            if let adherence = result.adherence {
                LabeledContent(String(localized: "Planned sets done"), value: adherence.formatted(.percent.precision(.fractionLength(0))))
            }
        } header: {
            MethodInfoHeader(title: "Adjusts Based on Your Progress", info: .volumeRecommendation)
        } footer: {
            if result.isHighVolume {
                Text("Over 20 sets a week is high volume: fine while you keep progressing and recovering.")
            }
        }
    }

    private var headline: String {
        switch result.action {
        case .keep: return String(localized: "Keep your current sets")
        case .add: return String(localized: "Add a few sets")
        case .reduce: return String(localized: "Ease off for a block")
        case .beConsistent: return String(localized: "Consistency first")
        case .needsMoreData: return String(localized: "Keep logging")
        }
    }

    private var detail: String {
        switch result.action {
        case .keep: return String(localized: "Your lifts for this muscle are still climbing.")
        case .add: return String(localized: "Strength has been flat with steady effort, so 10–20% more sets may help.")
        case .reduce: return String(localized: "Strength is slipping or the same weights feel harder, so try 20–33% fewer sets.")
        case .beConsistent: return String(localized: "Fewer than 80% of your planned sets were done. Hit the plan before adding more.")
        case .needsMoreData: return String(localized: "A few more weeks of workouts with this muscle will give a suggestion.")
        }
    }

    private var systemImage: String {
        switch result.action {
        case .keep: return Symbol.success
        case .add: return "arrow.up.circle"
        case .reduce: return "arrow.down.circle"
        case .beConsistent: return "calendar"
        case .needsMoreData: return Symbol.info
        }
    }

    private var tint: Color {
        switch result.action {
        case .keep: return .success
        case .reduce: return .warning
        case .add, .beConsistent, .needsMoreData: return .accentColor
        }
    }

    private func suggestedText(_ range: ClosedRange<Double>) -> String {
        range.lowerBound == range.upperBound
            ? Format.sets(range.lowerBound)
            : String(localized: "\(Format.repRange(Int(range.lowerBound), Int(range.upperBound))) sets")
    }

    private func trendText(_ percent: Double) -> String {
        let value = (percent / 100).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
        return String(localized: "\(value) a week")
    }
}
