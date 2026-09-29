//
//  CardioFitnessLevel.swift
//  DialedIn
//
//  Onboarding no longer asks for cardio fitness (decision 8c: it was collected but fed nothing).
//  The type stays because existing profiles store it and Profile > Account still edits it.
//

import Foundation

enum CardioFitnessLevel: String, CaseIterable, Codable {
    case beginner
    case novice
    case intermediate
    case advanced
    case elite
    
    var description: String {
        switch self {
        case .beginner:
            return String(localized: "Beginner")
        case .novice:
            return String(localized: "Novice")
        case .intermediate:
            return String(localized: "Intermediate")
        case .advanced:
            return String(localized: "Advanced")
        case .elite:
            return String(localized: "Elite")
        }
    }
    
    var detailDescription: String {
        switch self {
        case .beginner:
            return String(localized: "Just starting cardio, gets winded easily, low endurance")
        case .novice:
            return String(localized: "Some cardio experience, can handle light jogging, moderate endurance")
        case .intermediate:
            return String(localized: "Regular cardio, comfortable running, good endurance")
        case .advanced:
            return String(localized: "Experienced runner, high endurance, can maintain pace")
        case .elite:
            return String(localized: "Athlete level, exceptional endurance, competitive fitness")
        }
    }
}
