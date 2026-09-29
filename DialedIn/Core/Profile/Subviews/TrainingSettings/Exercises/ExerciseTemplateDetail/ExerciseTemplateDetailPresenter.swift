//
//  ExerciseModelDetailPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ExerciseModelDetailPresenter {
    private let interactor: ExerciseModelDetailInteractor
    private let router: ExerciseModelDetailRouter

    var section: CustomSection = .description

    var isBookmarked: Bool = false
    var isFavourited: Bool = false
    private(set) var unitPreference: ExerciseUnitPreference?

    init(
        interactor: ExerciseModelDetailInteractor,
        router: ExerciseModelDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    private(set) var stats = ExerciseModelDetailStats()

    /// Rebuilt on appear rather than computed per section: all three history-bearing tabs walk the
    /// same sessions, and the collection only changes when a workout is logged.
    func onViewAppear(delegate: ExerciseModelDetailDelegate) {
        unitPreference = interactor.getPreference(templateId: delegate.exerciseModel.id)
        stats = ExerciseModelDetailStats.make(
            from: interactor.workoutSessions,
            templateId: delegate.exerciseModel.id
        )
    }

    var performedSubtitle: String {
        guard let latest = stats.mostRecentFirst.first else { return "No history yet" }
        let times = stats.performances.count
        let noun = times == 1 ? String(localized: "time") : String(localized: "times")
        let date = latest.date.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "Performed \(String(describing: times)) \(noun) · last \(date)")
    }

    /// The unit the charts and figures are in.
    var weightUnit: ExerciseWeightUnit { unitPreference?.weightUnit ?? .kilograms }

    /// One point per session, so the charts follow workouts rather than calendar days — this
    /// exercise is not necessarily trained daily. In the user's own unit: sessions are stored in
    /// kilograms, and the chart used to plot those under a "kg" axis whatever the preference.
    var weightSeries: [TimeSeries] {
        let points = stats.performances
            .sorted { $0.date < $1.date }
            .map { TimeSeriesDatapoint(id: $0.sessionId, date: $0.date, value: weightInPreferredUnit($0.heaviestWeightKg)) }
        return [TimeSeries(name: "Top Set", data: points)]
    }

    private func weightInPreferredUnit(_ kilos: Double) -> Double {
        weightUnit == .pounds ? UnitConversion.kgToLbs(kilos) : kilos
    }

    /// Whole kilograms or pounds, as the rows show them, and a range that suits sessions rather
    /// than days: a lift is not trained daily, so D and W would often be empty.
    var weightChartConfiguration: ChartConfiguration {
        ChartConfiguration(
            unit: weightUnit.abbreviation,
            valueFormat: .number.precision(.fractionLength(0)),
            availableScales: [.month, .sixMonths, .year],
            initialScale: .month,
            seriesColors: [.orange],
            height: 220,
            accessibilityTitle: "Top Set"
        )
    }

    /// Reps are counted, so a bucket adds them up and the header shows the total.
    var repsChartConfiguration: ChartConfiguration {
        ChartConfiguration(
            aggregation: .sum,
            unit: "reps",
            valueFormat: .number.precision(.fractionLength(0)),
            availableScales: [.month, .sixMonths, .year],
            initialScale: .month,
            seriesColors: [.orange],
            height: 220,
            accessibilityTitle: "Reps Per Session"
        )
    }

    var repsSeries: [TimeSeries] {
        let points = stats.performances
            .sorted { $0.date < $1.date }
            .map { TimeSeriesDatapoint(id: $0.sessionId, date: $0.date, value: Double($0.totalReps)) }
        return [TimeSeries(name: "Reps", data: points)]
    }

    /// Sessions whose estimated 1-RM beat every session before it, newest first.
    var oneRMRecords: [ExerciseModelDetailStats.Performance] {
        var best: Double = 0
        var records: [ExerciseModelDetailStats.Performance] = []
        for performance in stats.performances.sorted(by: { $0.date < $1.date }) where performance.bestOneRMKg > best {
            best = performance.bestOneRMKg
            records.append(performance)
        }
        return records.reversed()
    }

    func formattedWeight(_ kilos: Double) -> String {
        String(format: "%.0f %@", weightInPreferredUnit(kilos), weightUnit.abbreviation)
    }

    func formattedVolume(_ kilos: Double) -> String {
        formattedWeight(kilos)
    }
        
    func onDismissPressed() {
        router.dismissScreen()
    }

    private(set) var isDeleting: Bool = false

    /// Only the author's own exercises can go; the seeded library is shared by everyone.
    func canDelete(exercise: ExerciseModel) -> Bool {
        !exercise.isSystemExercise && exercise.authorId == currentUser?.userId
    }

    func showDeleteConfirmation(exercise: ExerciseModel) {
        router.showAlert(title: String(localized: "Delete Exercise"), subtitle: String(localized: "Are you sure you want to delete '\(exercise.name)'? This action cannot be undone."), buttons: {
            AnyView(
                HStack {
                    Button("Delete", role: .destructive) {
                        Task {
                            await self.deleteExercise(exercise, onDismiss: { self.router.dismissScreen() })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            )
        })
    }

    /// `onDismiss` is the router's dismiss in the app; a parameter so a test can see it happen.
    func deleteExercise(_ exercise: ExerciseModel, onDismiss: @escaping () -> Void) async {
        isDeleting = true
        do {
            try await interactor.deleteExerciseModel(exerciseId: exercise.id)
            onDismiss()
        } catch {
            isDeleting = false
            router.showSimpleAlert(title: String(localized: "Failed to delete exercise"), subtitle: String(localized: "Please try again later"))
        }
    }
    
#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}

enum CustomSection: Hashable {
    case description
    case history
    case charts
    case records
}
