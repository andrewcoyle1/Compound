//
//  CheckInRecord.swift
//  Compound
//

import Foundation

/// The two dates that decide whether this week's check-in has already been dealt with.
///
/// Both are the *start of the ISO week*, not the moment of the tap, so "did I do this week" is a
/// comparison rather than an interval calculation. Skipping is remembered separately from
/// completing because they mean different things to everything except the card: one week of data
/// was reviewed, the other was waved past.
struct CheckInRecord: DataSyncModelProtocol {

    var id: String = CheckInRecord.documentId
    let authorId: String
    /// Start of the ISO week of the last completed check-in.
    var lastCompletedWeekStart: Date?
    var lastSkippedWeekStart: Date?

    static let documentId = "check_in_record"

    init(
        id: String = CheckInRecord.documentId,
        authorId: String,
        lastCompletedWeekStart: Date? = nil,
        lastSkippedWeekStart: Date? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.lastCompletedWeekStart = lastCompletedWeekStart
        self.lastSkippedWeekStart = lastSkippedWeekStart
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case lastCompletedWeekStart = "last_completed_week_start"
        case lastSkippedWeekStart = "last_skipped_week_start"
    }

    var eventParameters: [String: Any] {
        var dict: [String: Any] = [:]
        dict["check_in_last_completed_week_start"] = lastCompletedWeekStart
        dict["check_in_last_skipped_week_start"] = lastSkippedWeekStart
        return dict
    }

    static var mock: Self {
        CheckInRecord(authorId: "mock_user_123")
    }
}
