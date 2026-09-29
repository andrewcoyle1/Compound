//
//  Username.swift
//  DialedIn
//
//  The rules for a handle, in one place: the edit screen validates against them, the manager
//  refuses to claim anything else, and search uses them to decide whether a query could be one.
//  `firestore.rules` repeats the pattern for the reservation document id.
//

import Foundation

enum Username {

    static let minLength = 3
    static let maxLength = 20

    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")

    enum Validation: Equatable {
        case valid
        case tooShort
        case tooLong
        case invalidCharacters
        case edgeDot

        var message: String? {
            switch self {
            case .valid: nil
            case .tooShort: String(localized: "At least \(Username.minLength) characters")
            case .tooLong: String(localized: "At most \(Username.maxLength) characters")
            case .invalidCharacters: String(localized: "Letters, numbers, underscores and dots only")
            case .edgeDot: String(localized: "Can't start or end with a dot")
            }
        }
    }

    /// What the user typed, as it would be stored: trimmed, without a leading `@`, lowercase.
    static func normalised(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("@") { text.removeFirst() }
        return text.lowercased()
    }

    /// Checks an already-normalised handle.
    static func validate(_ handle: String) -> Validation {
        if !handle.allSatisfy(allowed.contains) { return .invalidCharacters }
        if handle.count < minLength { return .tooShort }
        if handle.count > maxLength { return .tooLong }
        if handle.hasPrefix(".") || handle.hasSuffix(".") { return .edgeDot }
        return .valid
    }

    static func isValid(_ handle: String) -> Bool {
        validate(handle) == .valid
    }

    /// How a people search runs. A query starting with `@` is only a handle; any other query is a
    /// name, and also a handle prefix when it could be the start of one (one word, handle charset).
    static func searchRoute(for query: String) -> (name: String?, handlePrefix: String?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = normalised(trimmed)
        let couldBeHandle = !prefix.isEmpty && prefix.count <= maxLength && prefix.allSatisfy(allowed.contains)
        if trimmed.hasPrefix("@") {
            return (nil, couldBeHandle ? prefix : nil)
        }
        return (trimmed.isEmpty ? nil : trimmed, couldBeHandle ? prefix : nil)
    }
}

enum UsernameError: LocalizedError, Equatable {
    case invalid
    case taken

    var errorDescription: String? {
        switch self {
        case .invalid: String(localized: "That username isn't valid.")
        case .taken: String(localized: "That username is taken.")
        }
    }
}
