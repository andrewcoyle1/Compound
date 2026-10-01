//
//  MetricAllDataView.swift
//  Compound
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// Every entry of a metric, newest first, like Health's "All Recorded Data": the value on the leading
/// edge and its date on the trailing edge, in one section headed with the metric's name. Pushed from
/// `MetricDetailView`'s "Show All Data" row, sharing its presenter.
struct MetricAllDataView<Presenter: MetricDetailPresenter>: View {

    let presenter: Presenter

    var body: some View {
        let configuration = presenter.configuration
        let entries = presenter.entries.sorted { $0.date > $1.date }

        List {
            Section {
                ForEach(entries) { entry in
                    row(entry, configuration: configuration)
                }
                // Only screens whose entries are stored here can delete them; the rest show values
                // derived from meals, workouts or the profile.
                .onDelete(perform: presenter.supportsDeletion ? { offsets in delete(offsets, from: entries) } : nil)
            } header: {
                Text(configuration.title)
            }
        }
        .overlay {
            // Deleting the last entry leaves the section empty.
            if entries.isEmpty {
                ContentUnavailableView(configuration.title, systemImage: Symbol.analytics, description: Text(configuration.emptyStateMessage))
            }
        }
        .navigationTitle("All Recorded Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presenter.supportsDeletion && !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func row(_ entry: Presenter.Entry, configuration: MetricConfiguration) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                // A macro row carries three values ("148g P · 214g C · 69.7g F"), so it scales down to
                // fit on one line rather than wrapping mid-item.
                Text(presenter.displayValue(for: entry))
                    .font(.rowTitle)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !configuration.unitText.isEmpty {
                    Text(configuration.unitText)
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.m)

            Text(entry.displayLabel)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func delete(_ offsets: IndexSet, from entries: [Presenter.Entry]) {
        let deleted = offsets.map { entries[$0] }
        Task {
            for entry in deleted {
                await presenter.onDeleteEntry(entry)
            }
        }
    }
}
