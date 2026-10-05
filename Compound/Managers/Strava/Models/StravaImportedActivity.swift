//
//  StravaImportedActivity.swift
//  Compound
//
//  An activity from the athlete's Strava account — a run, a ride — copied into
//  `users/{uid}/strava_activities` by the server, at connect and from Strava's webhook. Workouts
//  Compound uploaded are never imported back.
//
//  Strava's terms allow showing these to the athlete only: never on a screen someone else sees.
//

import Foundation

struct StravaImportedActivity: DataSyncModelProtocol, Equatable {
    let id: String
    let name: String
    let sportType: String
    let startDate: Date
    /// Seconds.
    let elapsedTime: Int
    let movingTime: Int
    /// Metres.
    let distance: Double
    let totalElevationGain: Double?
    let averageHeartrate: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, distance
        case sportType = "sport_type"
        case startDate = "start_date"
        case elapsedTime = "elapsed_time"
        case movingTime = "moving_time"
        case totalElevationGain = "total_elevation_gain"
        case averageHeartrate = "average_heartrate"
    }

    var stravaURL: URL? { URL(string: "https://www.strava.com/activities/\(id)") }

    static var mocks: [StravaImportedActivity] {
        [
            StravaImportedActivity(
                id: "1001", name: "Morning Run", sportType: "Run", startDate: Date().addingTimeInterval(-86_400),
                elapsedTime: 2_100, movingTime: 1_980, distance: 6_200, totalElevationGain: 45, averageHeartrate: 151
            ),
            StravaImportedActivity(
                id: "1002", name: "Evening Ride", sportType: "Ride", startDate: Date().addingTimeInterval(-3 * 86_400),
                elapsedTime: 4_000, movingTime: 3_700, distance: 32_400, totalElevationGain: 310, averageHeartrate: nil
            )
        ]
    }
}

/// A span's imported activities added up, `nil` when there were none.
struct StravaTotals: Equatable {
    let count: Int
    let distanceMeters: Double
    let movingTime: TimeInterval

    init(count: Int, distanceMeters: Double, movingTime: TimeInterval) {
        self.count = count
        self.distanceMeters = distanceMeters
        self.movingTime = movingTime
    }

    init?(_ activities: [StravaImportedActivity], in interval: DateInterval) {
        let inSpan = activities.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
        guard !inSpan.isEmpty else { return nil }
        self.init(
            count: inSpan.count,
            distanceMeters: inSpan.reduce(0) { $0 + $1.distance },
            movingTime: TimeInterval(inSpan.reduce(0) { $0 + $1.movingTime })
        )
    }
}
