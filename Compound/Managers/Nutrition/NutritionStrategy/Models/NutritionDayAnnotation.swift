//
//  NutritionDayAnnotation.swift
//  Compound
//

import Foundation

/// What the user told us about one day that the meal logs alone cannot say.
///
/// Two different kinds of "this day was not normal", and the expenditure engine treats them as
/// opposites. A partially logged day is evidence we do not have — the intake figure is wrong, so
/// the day is dropped. A fasting day is evidence we do have — the user ate nothing on purpose,
/// so zero is the real number and dropping it would flatter the mean.
///
/// The id is the `dayKey`, so saving an annotation for a day that already has one replaces it
/// rather than accumulating a second opinion about the same Tuesday.
struct NutritionDayAnnotation: DataSyncModelProtocol {

    var id: String { dayKey }
    /// `yyyy-MM-dd`, the same format as `MealLogModel.dayKey`.
    let dayKey: String
    let authorId: String
    /// Intake that day is incomplete, so the engine should not read it as a measurement.
    var isPartiallyLogged: Bool
    /// The user intentionally ate nothing or next to nothing; 0 kcal is the real figure.
    var isFastingDay: Bool
    var dateModified: Date

    init(
        dayKey: String,
        authorId: String,
        isPartiallyLogged: Bool = false,
        isFastingDay: Bool = false,
        dateModified: Date = .now
    ) {
        self.dayKey = dayKey
        self.authorId = authorId
        self.isPartiallyLogged = isPartiallyLogged
        self.isFastingDay = isFastingDay
        self.dateModified = dateModified
    }

    enum CodingKeys: String, CodingKey {
        case dayKey = "day_key"
        case authorId = "author_id"
        case isPartiallyLogged = "is_partially_logged"
        case isFastingDay = "is_fasting_day"
        case dateModified = "date_modified"
    }

    /// An annotation saying nothing is the same as no annotation, and is what the check-in writes
    /// when the user turns a toggle back off.
    var isEmpty: Bool {
        !isPartiallyLogged && !isFastingDay
    }

    var eventParameters: [String: Any] {
        [
            "annotation_day_key": dayKey,
            "annotation_is_partially_logged": isPartiallyLogged,
            "annotation_is_fasting_day": isFastingDay
        ]
    }

    static var mock: Self {
        NutritionDayAnnotation(dayKey: Date().dayKey, authorId: "mock_user_123")
    }
}
