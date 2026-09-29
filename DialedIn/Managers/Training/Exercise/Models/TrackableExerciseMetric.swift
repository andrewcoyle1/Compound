//
//  TrackableExerciseMetric.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

enum TrackableExerciseMetric: String, DataSyncModelProtocol, PickableItem {
    
    var id: String { self.rawValue }
    case reps
    case repsPerSide
    case weight
    case weightPerSide
    case weightPerSidePersistent
    case weightPerSideAssistance
    case duration
    case durationPerSide
    case distanceShort
    case distanceShortPerSide
    case distanceLong
    
    var name: String {
        switch self {
        case .reps: return String(localized: "Reps")
        case .repsPerSide: return String(localized: "Reps Per Side")
        case .weight: return String(localized: "Weight")
        case .weightPerSide: return String(localized: "Weight Per Side")
        case .weightPerSidePersistent: return String(localized: "Weight Per Side (Persistent)")
        case .weightPerSideAssistance: return String(localized: "Weight Per Side (Assistance)")
        case .duration: return String(localized: "Duration")
        case .durationPerSide: return String(localized: "Duration Per Side")
        case .distanceShort: return String(localized: "Distance Short")
        case .distanceShortPerSide: return String(localized: "Distance Short Per Side")
        case .distanceLong: return String(localized: "Distance Long")  
        }
    }

    var description: String? {
        switch self {
        case .reps: return String(localized: "Track the number of repetitions performed.")
        case .repsPerSide: return String(localized: "Track the number of repetitions performed per side.")
        case .weight: return String(localized: "Track the load used for each set.")
        case .weightPerSide: return String(localized: "Track the load used for each set per side.")
        case .weightPerSidePersistent: return String(localized: "Track singular weight used on both sides.")
        case .weightPerSideAssistance: return String(localized: "Track assisted or supported weight.")
        case .duration: return String(localized: "Track time for each set.")
        case .durationPerSide: return String(localized: "Track time for each set per side.")
        case .distanceShort: return String(localized: "Track short distances, like sprints or carries.")
        case .distanceShortPerSide: return String(localized: "Track short distances per side.")
        case .distanceLong: return String(localized: "Track long distances, like runs or rows.")
        }
    }
}
