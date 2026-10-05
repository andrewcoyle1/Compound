//
//  Symbols.swift
//  Compound
//

import SwiftUI

/// SF Symbol names. **One concept, one symbol. One symbol, one concept.** Write
/// `Image(systemName: Symbol.workout)` / `Label("…", systemImage: Symbol.workout)`, never a literal.
/// A fill variant (`Symbol.x + ".fill"`) is the same concept in a selected or emphasised state.
///
/// UI chrome the system owns stays out: `role: .close`, the disclosure chevron, the search tab.
///
/// Chosen from a sweep of every `systemImage:`/`systemName:` literal (2026-09-27). The audit's
/// collisions, and how each was resolved:
///
/// | Symbol | Meant | Now |
/// |---|---|---|
/// | `scalemass` | scale weight, volume, equipment, weight unit | `scaleWeight` only. Volume is `square.stack.3d.up`, equipment `dumbbell`, lifted weight `gauge.with.dots.needle.67percent` |
/// | `dumbbell` / `.fill` | workout, exercise, equipment, workout settings, training tab | `equipment` only. Workout is `figure.strengthtraining.traditional`, exercise `figure.strengthtraining.functional` |
/// | `figure.strengthtraining.traditional` | workout, exercise, assessment | `workout` only |
/// | `figure.run` | cardio, "no activity", add-action | `cardio` only |
/// | `map` | nutrition strategy, roadmap | `roadmap`. Strategy is `arrow.triangle.branch` |
/// | `book` / `book.closed` | legal, tutorials, knowledge base, recipes, food library | `recipe` (`book.closed`) only. Library is `books.vertical`, legal `doc.text`, tutorials `graduationcap`, knowledge base `lightbulb` |
/// | `list.bullet` | workout history, exercises, new exercise, nutrition overview | retired. History is `clock.arrow.circlepath`, nutrition `leaf` |
/// | `flame` / `.fill` | calories, expenditure, streak | `calories` only. Expenditure is `bolt.heart`, streak `calendar.badge.checkmark` |
/// | `target` | goal, warmup | `goal` only. Warmup is `thermometer.sun` |
/// | `calendar` | mesocycle schedule, date picker, weekly count | `calendar` (a date or schedule). Mesocycle is `list.bullet.clipboard` |
/// | `clock` / `timer` | duration, rest timer, meal times | `duration` and `rest` respectively |
enum Symbol {
    // Training
    static let workout = "figure.strengthtraining.traditional"
    static let exercise = "figure.strengthtraining.functional"
    static let set = "list.number"
    static let reps = "number"
    static let weight = "gauge.with.dots.needle.67percent"
    static let volume = "square.stack.3d.up"
    static let equipment = "dumbbell"
    static let gym = "building.2"
    static let duration = "clock"
    static let rest = "timer"
    static let restDay = "bed.double"
    static let warmup = "thermometer.sun"
    static let superset = "link"
    static let personalRecord = "trophy.fill"
    static let mesocycle = "list.bullet.clipboard"
    /// A macrocycle: mesocycles run one after another.
    static let macrocycle = "square.3.layers.3d"
    static let history = "clock.arrow.circlepath"
    static let library = "books.vertical"
    static let template = "rectangle.stack"
    static let cardio = "figure.run"
    static let muscleGroup = "figure.arms.open"
    static let note = "note.text"

    // Nutrition
    static let nutrition = "leaf"
    static let meal = "fork.knife"
    static let food = "basket"
    static let recipe = "book.closed"
    static let calories = "flame"
    static let protein = "bolt"
    static let carbs = "carrot"
    static let fat = "drop"
    static let expenditure = "bolt.heart"
    static let strategy = "arrow.triangle.branch"
    static let barcode = "barcode.viewfinder"
    static let camera = "camera"

    // Body and progress
    static let steps = "figure.walk"
    static let scaleWeight = "scalemass"
    static let bodyFat = "percent"
    static let measurement = "ruler"
    static let goal = "target"
    static let streak = "calendar.badge.checkmark"
    static let habits = "repeat"
    static let analytics = "chart.xyaxis.line"
    static let calendar = "calendar"

    // App and profile
    static let settings = "gearshape"
    static let notifications = "bell"
    static let profile = "person.crop.circle"
    static let friends = "person.2"
    static let roadmap = "map"
    static let knowledgeBase = "lightbulb"
    static let tutorials = "graduationcap"
    static let legal = "doc.text"

    // Actions
    static let add = "plus"
    /// Starting a workout now, as opposed to building one.
    static let start = "play"
    static let edit = "pencil"
    static let delete = "trash"
    static let close = "xmark"
    static let share = "square.and.arrow.up"
    static let search = "magnifyingglass"
    static let filter = "line.3.horizontal.decrease"
    static let more = "ellipsis"
    /// Skipping a planned workout so the next one moves up.
    static let skip = "forward.end"
    /// A menu that picks one of several, such as which microcycle of a mesocycle to show.
    static let choose = "chevron.up.chevron.down"
    static let repeatMacrocycle = "arrow.counterclockwise"
    static let logAgain = "arrow.counterclockwise"

    // Status
    static let info = "info.circle"
    static let success = "checkmark.circle.fill"
    static let warning = "exclamationmark.triangle"
    static let error = "exclamationmark.circle"
}
