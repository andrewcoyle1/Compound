//
//  Date+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Foundation

extension Date {
    static var random: Date {
        let randomInterval = TimeInterval.random(in: 0...2_000_000_000)
        return Date(timeIntervalSince1970: randomInterval)
    }
    
    static func random(in range: Range<TimeInterval>) -> Date {
        let randomtimeInterval = TimeInterval.random(in: range)
        return Date(timeIntervalSince1970: randomtimeInterval)
    }
    
    static func random(in range: ClosedRange<TimeInterval>) -> Date {
        let randomtimeInterval = TimeInterval.random(in: range)
        return Date(timeIntervalSince1970: randomtimeInterval)
    }
}
