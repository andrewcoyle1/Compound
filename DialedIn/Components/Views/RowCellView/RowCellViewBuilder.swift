//
//  ChatRowCellViewBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/8/24.
//

import SwiftUI

struct RowCellViewBuilder: View {
    
    var currentUserId: String? = ""
    var collection: Any?
    
    var getItems: () async -> [Any]?

    @State private var didLoadCollection: Bool = false
    @State private var didLoadItems: Bool = false
    @State private var didStartStreaming: Bool = false
    @State private var stopListening: (() -> Void)?
    
    @State private var items: [Any] = []
    
    private var isLoading: Bool {
        if didLoadItems {
            return false
        }
        
        return true
    }
    
    private var hasNewReview: Bool {
        // Commented out detailed logic due to lack of model info
        // Returning false as placeholder
        return false
    }
    
    private var subheadline: String? {
        if isLoading {
            return "xxxx xxxx xxxxx xxxx"
        }
        
        return String(localized: "Error")
    }
    
    // Placeholders for collection properties
    var collectionImageName: String {
        // Could be replaced by a closure to provide imageName if needed
        return Constants.randomImage
    }
    
    var collectionName: String {
        // Could be replaced by a closure to provide name if needed
        return String(localized: "Collection Name")
    }

    var body: some View {
        RowCellView(
            imageName: collectionImageName,
            headline: isLoading ? "xxxx xxxx" : collectionName,
            subheadline: subheadline,
            hasNewReview: isLoading ? false : hasNewReview,
            trailingBadge: trailingBadge
        )
        .redacted(reason: isLoading ? .placeholder : [])
        .task {
            await loadItemsIfNeeded()
            await streamItems()
        }
        .onDisappear {
            stopListening?()
            stopListening = nil
            didStartStreaming = false
        }
        
    }

    private var trailingBadge: String? {
        // Commented out detailed logic due to lack of model info
        // Return nil as placeholder
        return nil
    }
    
    private func loadItemsIfNeeded() async {
        guard !didLoadItems else { return }
        didLoadItems = true
        if let fetched = await getItems() {
            items = fetched
        } else {
            items = []
        }
    }

    private func streamItems() async {
        guard !didStartStreaming else { return }
        didStartStreaming = true

    }
}

#Preview {
    VStack {
        RowCellViewBuilder(getItems: {
            try? await Task.sleep(for: .seconds(1))
            return [Any]() // Empty placeholder array
        })
        RowCellViewBuilder(getItems: {
            try? await Task.sleep(for: .seconds(1))
            return [Any]() // Empty placeholder array
        })
    }
}
