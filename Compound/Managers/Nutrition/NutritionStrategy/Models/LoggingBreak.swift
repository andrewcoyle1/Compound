//
//  LoggingBreak.swift
//  Compound
//

import Foundation

/// A stretch of days the user has told us not to judge them on.
///
/// One document per user, because a break is a state rather than a history: the only questions
/// anyone asks are "is one open" and "when did it start". While it is open the expenditure
/// estimate freezes at `startDate` and no check-in comes due, which is the whole point — a break
/// from logging that still nagged weekly would not be a break.
struct LoggingBreak: DataSyncModelProtocol {

    var id: String = LoggingBreak.documentId
    let authorId: String
    var startDate: Date
    /// `nil` means open-ended, until the user ends it.
    var endDate: Date?

    static let documentId = "logging_break"

    init(
        id: String = LoggingBreak.documentId,
        authorId: String,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.startDate = startDate
        self.endDate = endDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    /// Open when it has begun and has not been ended.
    ///
    /// A break whose start is in the future is not open yet. Nothing in the app creates one, but a
    /// clock that moved backwards should not freeze the estimate on a day that has not happened.
    func isOpen(on date: Date) -> Bool {
        endDate == nil && startDate <= date
    }

    /// Whether `day` falls inside the break, end date included.
    func contains(_ day: Date) -> Bool {
        guard day >= startDate else { return false }
        guard let endDate else { return true }
        return day <= endDate
    }

    var eventParameters: [String: Any] {
        var dict: [String: Any] = ["logging_break_start_date": startDate]
        dict["logging_break_end_date"] = endDate
        return dict
    }

    static var mock: Self {
        LoggingBreak(authorId: "mock_user_123", startDate: Date(), endDate: Date())
    }
}
