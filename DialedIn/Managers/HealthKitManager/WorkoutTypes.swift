//
//  WorkoutTypes.swift
//  DialedIn
//
//  Created by Andrew Coyle on 30/09/2025.
//

import Foundation
import HealthKit

struct WorkoutTypes {
    static let supported: [HKWorkoutActivityType] = [
        .traditionalStrengthTraining
    ]

    static func shouldDisambiguateLocation(for activityType: HKWorkoutActivityType) -> Bool {
        switch activityType {
        default:
            return false
        }
    }

    static var workoutConfigurations: [HKWorkoutConfiguration] {
        var configurations: [HKWorkoutConfiguration] = []
        supported.forEach { activityType in
            if shouldDisambiguateLocation(for: activityType) {
                let outdoorConfiguration = HKWorkoutConfiguration()
                outdoorConfiguration.activityType = activityType
                outdoorConfiguration.locationType = .outdoor
                configurations.append(outdoorConfiguration)

                let indoorConfiguration = HKWorkoutConfiguration()
                indoorConfiguration.activityType = activityType
                indoorConfiguration.locationType = .indoor
                configurations.append(indoorConfiguration)
            } else {
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = activityType
                configurations.append(configuration)
            }
        }
        return configurations
    }

    static func distanceQuantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        default:
            return nil
        }
    }

    static func speedQuantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        default:
            return nil
        }
    }
}

extension HKWorkoutConfiguration {

    var name: String {
        if WorkoutTypes.shouldDisambiguateLocation(for: activityType) {
            return "\(locationType) \(activityType.name)"
        } else {
            return activityType.name
        }
    }

    var symbol: String {
        switch activityType {
        default:
            return activityType.symbol
        }
    }

    var supportsDistance: Bool {
        if WorkoutTypes.distanceQuantityType(for: activityType) != nil {
            return locationType == .indoor ? false : true
        }
        return false
    }

    var supportsSpeed: Bool {
        if WorkoutTypes.speedQuantityType(for: activityType) != nil {
            return locationType == .indoor ? false : true
        }
        return false
    }
}

extension HKWorkoutActivityType {

    var name: String {
        switch self {
        case .running:
            return String(localized: "Run")
        case .cycling:
            return String(localized: "Cycle")
        case .walking:
            return String(localized: "Walk")
        case .rowing:
            return String(localized: "Row")
        case .yoga:
            return String(localized: "Yoga")
        case .traditionalStrengthTraining:
            return String(localized: "Strength Training")
        default:
            return ""
        }
    }

    var symbol: String {
        switch self {
        case .running:
            return "figure.run"
        case .cycling:
            return "figure.outdoor.cycle"
        case .walking:
            return "figure.walk"
        case .rowing:
            return "figure.outdoor.rowing"
        case .yoga:
            return "figure.yoga"
        case .traditionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        default:
            return "exclamationmark.questionmark"
        }
    }
}

extension HKWorkoutSessionLocationType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .indoor:
            String(localized: "Indoor")
        case .outdoor:
            String(localized: "Outdoor")
        case .unknown:
            String(localized: "Unknown")
        @unknown default:
            // A location type added in a later SDK must not crash a description.
            String(localized: "Unknown")
        }
    }
}
