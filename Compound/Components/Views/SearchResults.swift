//
//  SearchResults.swift
//  Compound
//
//  What the tabs' own search fields share. There is no Search tab: Training searches exercises and
//  workouts, Nutrition foods and recipes, Social people. They match the same way and draw their
//  result rows the same way.
//

import SwiftUI

protocol SearchListItem: Identifiable {
    var id: String { get }
    var name: String { get }
    var description: String? { get }
    var imageURL: String? { get }
}

/// Every collection is matched the same way: a substring of the normalised query against each
/// normalised field.
enum SearchMatch {

    static func normalised(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .alphanumerics.inverted)
            .lowercased()
    }

    /// False for a blank query, so a caller never has to ask whether it is searching.
    static func matches(_ query: String, _ fields: [String?]) -> Bool {
        let query = normalised(query)
        guard !query.isEmpty else { return false }
        return fields.contains { $0.map { normalised($0).contains(query) } == true }
    }

    static func isSearching(_ query: String) -> Bool {
        !normalised(query).isEmpty
    }
}

/// One titled group of results, each row opening its item.
struct SearchResultSection<Item: SearchListItem>: View {

    let title: String
    let items: [Item]
    let onPressed: (Item) -> Void

    var body: some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button {
                        onPressed(item)
                    } label: {
                        ListRow(title: item.name, subtitle: item.description, imageName: item.imageURL, accessory: .chevron)
                            .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text(title)
            }
        }
    }
}
