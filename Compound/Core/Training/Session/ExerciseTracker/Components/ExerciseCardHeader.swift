//
//  ExerciseCardHeader.swift
//  Compound
//
//  The live card's title row.
//

import SwiftUI

/// The exercise's name, with its bodyweight badge and its menu. On a superset's card it is a
/// member's line: its label ("B1") before the name, and no menu, as the superset has one for all.
/// Kept short: the sets are the point, and the notes follow them.
struct ExerciseCardHeader<Menu: View>: View {

    let name: String
    var memberLabel: String?
    var bodyweight: BodyweightContribution?
    @ViewBuilder let menu: () -> Menu

    var body: some View {
        Group {
            if let bodyweight, bodyweight.contributionKg != nil {
                ViewThatFits(in: .horizontal) {
                    titleRow {
                        BodyweightContributionBadge(contribution: bodyweight)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        titleRow {
                            EmptyView()
                        }
                        BodyweightContributionBadge(contribution: bodyweight)
                    }
                }
            } else {
                titleRow {
                    EmptyView()
                }
            }
        }
        .textCase(nil)
    }

    /// The name, then `trailing`, then the menu, on one line, so the menu reads as the exercise's own.
    private func titleRow(@ViewBuilder trailing: () -> some View) -> some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            if let memberLabel {
                Chip(memberLabel, systemImage: Symbol.superset, tint: .superset)
                    .accessibilityLabel(String(localized: "Superset member \(memberLabel)"))
            }
            // Under the superset's own title a member's name is a row's, not a section's.
            Text(name)
                .font(memberLabel == nil ? .sectionTitle : .rowTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
            if memberLabel == nil {
                menu()
            }
        }
    }
}

#Preview {
    List {
        Section {
            Label("Add", image: "plus")
        } header: {
            ExerciseCardHeader(
                name: "Bench Press",
                memberLabel: nil,
                bodyweight: nil) {
                    Button {
                        
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
        }
    }
}
