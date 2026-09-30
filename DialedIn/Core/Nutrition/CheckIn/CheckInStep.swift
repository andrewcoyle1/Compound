//
//  CheckInStep.swift
//  DialedIn
//

import Foundation

/// The modules of the weekly check-in, in the order the Strategy settings screen names them.
///
/// The order is the declaration order and nothing else decides it, because the screen has
/// promised this sequence to the user since before any of it worked.
enum CheckInStep: String, CaseIterable, Identifiable, Sendable {
    case introduction
    case partialLogging
    case weighIn
    case fasting
    case loggingBreak
    case programUpdate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .introduction:   return String(localized: "Your Week")
        case .partialLogging: return String(localized: "Partial Logging")
        case .weighIn:        return String(localized: "Weigh-In")
        case .fasting:        return String(localized: "Fasting")
        case .loggingBreak:   return String(localized: "Logging Break")
        case .programUpdate:  return String(localized: "Program Update")
        }
    }

    /// The analytics name, which is also what every event carries as its `step` parameter.
    var eventName: String { rawValue }
}

/// One day of the reviewed week, as the partial-logging and fasting lists show it.
struct CheckInDayRow: Identifiable, Equatable, Sendable {
    var id: String { dayKey }
    let dayKey: String
    let date: Date
    /// The day's logged intake, or nil when nothing was logged at all.
    let intakeKcal: Double?
    /// The row's toggle: "Incomplete" on the partial list, "Fasted" on the fasting list.
    var isOn: Bool

    var isLogged: Bool { intakeKcal != nil }

    var weekdayName: String {
        date.formatted(.dateTime.weekday(.wide))
    }

    var intakeDescription: String {
        guard let intakeKcal else { return String(localized: "Nothing logged") }
        return Format.kcal(intakeKcal)
    }
}
