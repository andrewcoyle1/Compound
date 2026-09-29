//
//  TextValidationHelper.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/11/24.
//
import Foundation

struct TextValidationHelper {
    
    static func checkIfTextIsValid(text: String, minimumCharacterCount: Int = 4) throws {
        guard text.count >= minimumCharacterCount else {
            throw TextValidationError.notEnoughCharacters(min: minimumCharacterCount)
        }
        
        let badWords: [String] = [
            "shit", "bitch", "ass"
        ]
        
        if badWords.contains(text.lowercased()) {
            throw TextValidationError.hasBadWords
        }
    }

    enum TextValidationError: LocalizedError {
        case notEnoughCharacters(min: Int)
        case hasBadWords
        
        var errorDescription: String? {
            switch self {
            case .notEnoughCharacters(min: let min):
                return String(localized: "Please add at least \(min) characters.")
            case .hasBadWords:
                return String(localized: "Bad word detected. Please rephrase your message.")
            }
        }
    }
}
