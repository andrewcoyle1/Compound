import SwiftUI

/// One muscle's weekly working sets against its recommended range.
struct MuscleBalanceRow: Identifiable, Equatable {
    let muscle: Muscles
    /// Twelve rolling weeks, oldest first; the last is the current seven days.
    let weeklySets: [Double]
    var id: Muscles { muscle }
    var currentSets: Double { weeklySets.last ?? 0 }
    var range: ClosedRange<Double> { MuscleVolume.recommendedWeeklySets(for: muscle) }
    var status: MuscleBalanceStatus { MuscleVolume.classify(sets: currentSets, for: muscle) }
}

@Observable
@MainActor
class MuscleBalancePresenter {

    static let weeks = 12

    private let interactor: MuscleBalanceInteractor
    private let router: MuscleBalanceRouter
    private let calendar: Calendar

    private(set) var rows: [MuscleBalanceRow] = []
    private(set) var endDate = Date()
    private(set) var selectedMuscle: Muscles?

    var upperRows: [MuscleBalanceRow] { rows.filter { $0.muscle.bodyRegion == .upperBody } }
    var lowerRows: [MuscleBalanceRow] { rows.filter { $0.muscle.bodyRegion == .lowerBody } }

    var selectedRow: MuscleBalanceRow? {
        rows.first { $0.muscle == selectedMuscle }
    }

    init(interactor: MuscleBalanceInteractor, router: MuscleBalanceRouter, calendar: Calendar = .current) {
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func loadData(endDate: Date = Date()) {
        self.endDate = endDate
        let completed = interactor.workoutSessions.filter { $0.endedAt != nil }
        let templates = Dictionary(interactor.allExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let weekly = MuscleVolume.weeklySets(
            sessions: completed,
            templates: templates,
            calendar: calendar,
            endDate: endDate,
            weeks: Self.weeks
        )
        rows = Muscles.allCases.map { MuscleBalanceRow(muscle: $0, weeklySets: weekly[$0] ?? []) }
    }

    /// Tapping a muscle shows its trend; tapping it again hides it.
    func onMusclePressed(_ muscle: Muscles) {
        selectedMuscle = selectedMuscle == muscle ? nil : muscle
        interactor.trackEvent(event: Event.onMusclePressed(muscle: muscle))
    }

    /// The sparkline's points, each week plotted at the day it ends.
    func sparklineData(for row: MuscleBalanceRow) -> [(date: Date, value: Double)] {
        let endDay = calendar.startOfDay(for: endDate)
        let count = row.weeklySets.count
        return row.weeklySets.enumerated().compactMap { index, value in
            calendar.date(byAdding: .day, value: -7 * (count - 1 - index), to: endDay).map { ($0, value) }
        }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension MuscleBalancePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onMusclePressed(muscle: Muscles)

        var eventName: String {
            switch self {
            case .onAppear:        return "MuscleBalanceView_Appear"
            case .onMusclePressed: return "MuscleBalanceView_Muscle_Press"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onMusclePressed(let muscle): return ["muscle": muscle.rawValue]
            case .onAppear:                    return nil
            }
        }

        var type: LogType { .analytic }
    }
}
