//
//  NudgeHistoryManager.swift
//  DialedIn
//
//  Who the user has nudged today, so each person is nudged at most once per local day. Kept on
//  the device, like recent searches: it only decides whether the Dashboard offers the button.
//

import Foundation

@MainActor
enum NudgeHistoryManager {
    private static let userDefaultsKey = "nudged_user_ids_today"

    /// One day's nudges. A record for any other day reads as empty, so yesterday's list is
    /// replaced by today's first nudge rather than piling up a key per day.
    private struct Record: Codable {
        let dayKey: String
        let userIds: [String]
    }

    static func nudgedUserIds(on date: Date = .now, userDefaults: UserDefaults = .standard) -> Set<String> {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.dayKey == date.dayKey else {
            return []
        }
        return Set(record.userIds)
    }

    static func addNudge(userId: String, on date: Date = .now, userDefaults: UserDefaults = .standard) {
        let ids = nudgedUserIds(on: date, userDefaults: userDefaults).union([userId])
        let record = Record(dayKey: date.dayKey, userIds: ids.sorted())
        if let data = try? JSONEncoder().encode(record) {
            userDefaults.set(data, forKey: userDefaultsKey)
        }
    }
}
