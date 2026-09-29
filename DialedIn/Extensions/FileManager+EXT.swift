//
//  FileManager+EXT.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/12/24.
//
import Foundation

extension FileManager {
    
    static func saveDocument<T: Codable>(key: String, value: T?) throws {
        let data = try JSONEncoder().encode(value)
        let url = getDocumentURL(for: key)
        try data.write(to: url)
    }
    
    static func getDocument<T: Codable>(key: String) throws -> T? {
        let url = getDocumentURL(for: key)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    static func getDocumentURL(for key: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            // Safe: the user-domain documents directory always exists on iOS.
            .first!
            .appendingPathComponent("\(key).txt")
    }
}
