import SwiftUI

@MainActor
protocol HabitsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)]
}

extension CoreInteractor: HabitsInteractor { }
