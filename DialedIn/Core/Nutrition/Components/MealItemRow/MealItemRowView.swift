//
//  MealItemRowView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import SwiftUI

/// One logged food, as a row in the nutrition timeline or in a meal's detail.
///
/// The row takes the item and the time to show beside it — not the whole `MealLogModel`. It used
/// to take the meal and work out for itself whether `item` was the first one in it, which meant
/// every host had to hand over a meal even when it had no timeline to align.
struct MealItemRowView: View {

    @Environment(\.colorScheme) private var colorScheme

    let item: MealItemModel

    /// The time to print in the gutter, or nil to hold the space without printing one — which is
    /// every row but a meal's first.
    var timestamp: Date?

    var style: MealItemRowStyle = MealItemRowStyle()

    var onEditPressed: (MealItemModel) -> Void

    var body: some View {
        HStack {
            if style.showsTimestampColumn && style.timestampSide == .left {
                timestampColumn
            }

            itemLabel

            if style.showsTimestampColumn && style.timestampSide == .right {
                timestampColumn
            }
        }
        .removeListRowFormatting()
    }

    /// A `ZStack` rather than a bare `if`: the column has to occupy its width on every row, or the
    /// rows under a meal's first one would slide left out of the column.
    private var timestampColumn: some View {
        ZStack {
            if let timestamp {
                Text(timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(style.timestampColumnEdge, 24)
            }
        }
        .frame(width: style.timestampColumnWidth, alignment: style.timestampAlignment)
    }

    private var itemLabel: some View {
        MealItemLabel(
            mealItem: item,
            showImage: style.showsImage,
            showCalories: style.showsCalories,
            showMacros: style.showsMacros,
            onEditPressed: onEditPressed
        )
        .padding()
        .background(
            colorScheme.backgroundPrimary,
            in: .containerRelative
        )
    }
}

// MARK: - Previews

/// Timestamps on: the first row of the meal prints the time, the rest hold the column.
#Preview("In a timeline") {
    @Previewable @State var mealLogModel: MealLogModel = MealLogModel.mock

    List {
        Section {
            ForEach(mealLogModel.items) { item in
                MealItemRowView(
                    item: item,
                    timestamp: item.id == mealLogModel.items.first?.id ? mealLogModel.date : nil,
                    onEditPressed: { print($0.displayName) }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        mealLogModel.items.removeAll { $0.id == item.id }
                    }
                }
            }
        }
        .listSectionMargins(.vertical, 4)
        .listRowSeparator(.hidden)
    }
}

/// Timestamps off, as `MealDetailView` shows them: no gutter at all, so nothing is indented
/// against empty space.
#Preview("Meal detail style") {
    List {
        Section {
            ForEach(MealLogModel.mock.items) { item in
                MealItemRowView(
                    item: item,
                    style: .mealDetail,
                    onEditPressed: { _ in }
                )
            }
        }
        .listRowSeparator(.hidden)
    }
}

/// The name alone, as the "Hide Food Details" setting renders it.
#Preview("Details hidden") {
    List {
        Section {
            ForEach(MealLogModel.mock.items) { item in
                MealItemRowView(
                    item: item,
                    timestamp: MealLogModel.mock.date,
                    style: MealItemRowStyle(showsImage: false, showsCalories: false, showsMacros: false),
                    onEditPressed: { _ in }
                )
            }
        }
        .listRowSeparator(.hidden)
    }
}

/// Timestamps on the trailing edge, where the gutter's inset has to flip with it.
#Preview("Timestamp on the right") {
    List {
        Section {
            ForEach(MealLogModel.mock.items) { item in
                MealItemRowView(
                    item: item,
                    timestamp: item.id == MealLogModel.mock.items.first?.id ? MealLogModel.mock.date : nil,
                    style: MealItemRowStyle(timestampSide: .right),
                    onEditPressed: { _ in }
                )
            }
        }
        .listRowSeparator(.hidden)
    }
}
