//
//  ParseServingSize.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

func parseServingSize(_ servingString: String) -> (portionSize: Double, portionName: String) {
    let trimmed = servingString.trimmingCharacters(in: .whitespaces)
    let pattern = #"^(\d+(?:\.\d+)?)\s*([^\d].*)$"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
       let numRange = Range(match.range(at: 1), in: trimmed),
       let nameRange = Range(match.range(at: 2), in: trimmed),
       let qty = Double(String(trimmed[numRange])) {
        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return (portionSize: qty, portionName: name) }
    }
    return (portionSize: 1.0, portionName: trimmed)
}
