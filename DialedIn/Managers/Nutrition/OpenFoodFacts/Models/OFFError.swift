//
//  OFFError.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

enum OFFError: LocalizedError {
    case productNotFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .productNotFound: return String(localized: "Product not found. Try a different barcode.")
        case .invalidResponse: return String(localized: "Invalid response from Open Food Facts.")
        }
    }
}
