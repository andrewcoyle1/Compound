//
//  StravaActivity.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

struct StravaActivity: Encodable {
    let name: String
    let sportType: String
    let startDateLocal: String
    let elapsedTime: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case sportType = "sport_type"
        case startDateLocal = "start_date_local"
        case elapsedTime = "elapsed_time"
        case description
    }
}
