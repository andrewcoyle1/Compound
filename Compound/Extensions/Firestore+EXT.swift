//
//  Firestore+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

@preconcurrency import FirebaseFirestore

// MARK: - Query Extensions

typealias FieldValue = FirebaseFirestore.FieldValue

extension Query {
    
    /// Fetches all documents from a query and decodes them to the specified type
    func getAllDocuments<T: Decodable>() async throws -> [T] {
        let snapshot = try await self.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: T.self)
        }
    }
}
