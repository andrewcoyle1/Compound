//
//  MealLogModel+Repeat.swift
//  Compound
//

import Foundation

extension MealLogModel {

    /// This meal logged again at `date`: a fresh `mealId`, so it is a new entry rather than a
    /// move, with the same items and notes.
    func copy(at date: Date, authorId: String) -> MealLogModel {
        MealLogModel(
            authorId: authorId,
            dayKey: date.dayKey,
            date: date,
            items: items,
            notes: notes
        )
    }

    /// This meal logged again on `destination`'s day at its own time of day, which is what Copy
    /// Day does to each meal.
    func copy(onDayOf destination: Date, authorId: String) -> MealLogModel {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let moved = calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: destination
        ) ?? destination
        return copy(at: moved, authorId: authorId)
    }
}

extension Array where Element == MealLogModel {

    /// Every food item logged in these meals, newest first: meals by date, and within a meal the
    /// item added last first. The meal store is not kept in date order, so walking it as stored
    /// put an old meal's foods ahead of this morning's.
    var ingredientItemsNewestFirst: [MealItemModel] {
        sorted { $0.date > $1.date }
            .flatMap { $0.items.reversed() }
            .filter { $0.sourceType == .ingredient }
    }
}
