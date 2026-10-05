//
//  StravaUploadStatus.swift
//  Compound
//
//  What `POST /uploads` and `GET /uploads/{id}` answer. Processing is asynchronous: the activity
//  id appears once Strava has made the activity, or `error` says why it did not.
//

struct StravaUploadStatus: Decodable, Equatable {
    let id: Int
    let error: String?
    let activityId: Int?

    enum CodingKeys: String, CodingKey {
        case id, error
        case activityId = "activity_id"
    }

    /// The activity an upload duplicates. Strava refuses a second upload with the same
    /// `external_id` ("… duplicate of activity 21234316"), which is the first one succeeding.
    var duplicateActivityId: Int? {
        guard let error, let range = error.range(of: "duplicate of activity ") else { return nil }
        return Int(error[range.upperBound...].prefix { $0.isNumber })
    }
}
