//
//  Samples+Body.swift
//  CompoundUnitTests
//
//  The fixed body and goal samples behind contracts/firestore/{body_measurement,steps,
//  analytics_settings,weight_goal}. See FirestoreContractTests.swift.
//

import Foundation
@testable import Compound

extension Samples {
    static let fullBodyMeasurement = BodyMeasurementEntry(
        id: "body_measurement_contract_full",
        authorId: "user_contract_full",
        weightKg: 82.25,
        bodyFatPercentage: 18.5,
        neckCircumference: 38.5,
        shoulderCircumference: 120.25,
        bustCircumference: 99.5,
        chestCircumference: 101.75,
        waistCircumference: 84.5,
        hipCircumference: 96.25,
        leftBicepCircumference: 35.5,
        rightBicepCircumference: 36.25,
        leftForearmCircumference: 29.5,
        rightForearmCircumference: 29.75,
        leftWristCircumference: 17.25,
        rightWristCircumference: 17.5,
        leftThighCircumference: 58.5,
        rightThighCircumference: 58.75,
        leftCalfCircumference: 38.25,
        rightCalfCircumference: 38.5,
        leftAnkleCircumference: 22.25,
        rightAnkleCircumference: 22.5,
        progressPhotoURLs: ["https://example.com/front.jpg", "https://example.com/side.jpg"],
        date: date("2026-10-12T06:45:00.250Z"),
        source: .healthkit,
        notes: "Morning, fasted",
        dateCreated: date("2026-10-12T06:46:10.500Z"),
        deletedAt: date("2026-10-13T09:00:00.125Z"),
        healthKitUUID: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")
    )

    static let minimalBodyMeasurement = BodyMeasurementEntry(
        id: "body_measurement_contract_minimal",
        authorId: "user_contract_minimal",
        date: date("2026-10-13T07:00:00.000Z"),
        source: .imported,
        dateCreated: date("2026-10-13T07:00:00.000Z")
    )

    static let fullSteps = StepsModel(
        id: "steps_contract_full",
        authorId: "user_contract_full",
        number: 10_432,
        date: date("2026-10-12T00:00:00.000Z"),
        source: .healthkit,
        dateCreated: date("2026-10-12T22:10:05.250Z"),
        dateModified: date("2026-10-12T23:55:40.750Z"),
        deletedAt: date("2026-10-13T09:00:00.125Z"),
        healthKitId: "healthkit-steps-1760227200"
    )

    static let minimalSteps = StepsModel(
        id: "steps_contract_minimal",
        authorId: "user_contract_minimal",
        number: 0,
        date: date("2026-10-13T00:00:00.000Z"),
        source: .manual,
        dateCreated: date("2026-10-13T08:00:00.000Z"),
        dateModified: date("2026-10-13T08:00:00.000Z")
    )

    static let fullAnalyticsSettings = AnalyticsSettings(
        authorId: "user_contract_full",
        hiddenSectionIds: [AnalyticsSection.muscleGroups.rawValue, AnalyticsSection.exercises.rawValue],
        dailyStepGoal: 12_000
    )

    static let fullWeightGoal = WeightGoal(
        userId: "user_contract_full",
        objective: .gainWeight,
        startingWeightKg: 64.5,
        targetWeightKg: 70.25,
        weeklyChangeKg: 0.25,
        createdAt: date("2026-08-01T09:30:00.500Z"),
        status: .completed,
        completedAt: date("2026-10-10T18:00:00.250Z"),
        id: "goal_contract_full"
    )

    /// No id, so it takes the user's, as goals saved before goal ids did.
    static let minimalWeightGoal = WeightGoal(
        userId: "user_contract_minimal",
        objective: .loseWeight,
        startingWeightKg: 84.5,
        targetWeightKg: 78.5,
        weeklyChangeKg: 0.5,
        createdAt: date("2026-09-01T08:00:00.000Z")
    )
}
