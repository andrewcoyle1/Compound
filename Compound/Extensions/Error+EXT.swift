//
//  Error+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 20/07/2025.
//

import Foundation

extension Error {
    var eventParameters: [String: Any] {
        let nsError = self as NSError
        var params: [String: Any] = [
            "error_description": localizedDescription,
            "error_domain": nsError.domain,
            "error_code": nsError.code
        ]
        // Include userInfo payload if present (flatten shallow keys to primitives/strings where possible)
        for (key, value) in nsError.userInfo {
            switch value {
            case let str as String:
                params[key] = str
            case let num as NSNumber:
                params[key] = num
            case let url as URL:
                params[key] = url.absoluteString
            default:
                // Fallback to String(description:)
                params[key] = String(describing: value)
            }
        }
        return params
    }
}

struct AppError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        return message
    }
}
