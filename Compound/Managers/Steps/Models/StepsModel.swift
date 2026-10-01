//
//  StepsEntry.swift
//  Compound
//
//  Created by Andrew Coyle on 07/02/2026.
//

import Foundation

struct StepsModel: DataSyncModelProtocol {
    let id: String
    let authorId: String
    var number: Int
    let date: Date
    let source: StepsSource
    let dateCreated: Date
    var dateModified: Date
    let deletedAt: Date?
    let healthKitId: String?

    init(
        id: String = UUID().uuidString,
        authorId: String,
        number: Int,
        date: Date,
        source: StepsSource = .manual,
        dateCreated: Date = Date.now,
        dateModified: Date = Date.now,
        deletedAt: Date? = nil,
        healthKitId: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.number = number
        self.date = date
        self.source = source
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.deletedAt = deletedAt
        self.healthKitId = healthKitId
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case number
        case date
        case source
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case deletedAt = "deleted_at"
        case healthKitId = "healthkit_id"
    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "steps_\(CodingKeys.id.rawValue)": id,
            "steps_\(CodingKeys.authorId.rawValue)": authorId,
            "steps_\(CodingKeys.number.rawValue)": number,
            "steps_\(CodingKeys.date.rawValue)": date,
            "steps_\(CodingKeys.source.rawValue)": source.rawValue,
            "steps_\(CodingKeys.dateCreated.rawValue)": dateCreated,
            "steps_\(CodingKeys.dateModified.rawValue)": dateModified,
            "steps_\(CodingKeys.deletedAt.rawValue)": deletedAt,
            "steps_\(CodingKeys.healthKitId.rawValue)": healthKitId
        ]
        return dict.compactMapValues({ $0 })

    }
    
    static var mock: StepsModel {
        mocks[0]
    }
    
    /// Four months of daily steps with a weekday/weekend rhythm and the odd rest day,
    /// so the steps chart and streaks have a real shape. Was eight identical 3,000-step
    /// days, which rendered as a flat line.
    static let mocks: [StepsModel] = (0..<120).map { daysAgo in
        let date = Date.now.addingTimeInterval(days: -daysAgo)
        let weekday = Calendar.current.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        let base = isWeekend ? 5_200 : 9_400
        // Deterministic wobble so the series looks organic but never changes between runs.
        let wobble = Int(2_600 * sin(Double(daysAgo) * 1.7))
        let slowBuild = (120 - daysAgo) * 8 // gradually more active over time
        let isRestDay = daysAgo % 23 == 0

        let number = isRestDay ? 1_800 : max(1_200, base + wobble + slowBuild)

        return StepsModel(
            authorId: UserModel.mock.userId,
            number: number,
            date: date
        )
    }

}

enum StepsSource: String, Codable {
    case manual
    case healthkit
    case imported

    var displayName: String {
        switch self {
        case .manual: return "Manual Entry"
        case .healthkit: return "HealthKit"
        case .imported: return "Imported"
        }
    }
}
