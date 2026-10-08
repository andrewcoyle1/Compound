import SwiftUI

/// How a template exercise's targets change from week to week of a mesocycle: a list of overrides,
/// each taking over from its week until the next. Every change goes straight back to the set-target
/// editor's working copy, so that editor's Save and Cancel still decide whether any of it is kept.
@Observable
@MainActor
class MicrocycleVariationsPresenter {

    /// An override with an id of its own, so its row keeps its identity while its week is stepped.
    struct Variation: Identifiable, Equatable {
        let id: String
        var fromMicrocycle: Int
        var setTargets: [SetTarget]
    }

    /// Week 1 is the exercise's own targets, so a variation starts from week 2.
    static let weekRange = 2...52

    private let interactor: MicrocycleVariationsInteractor
    private let router: MicrocycleVariationsRouter
    private let onChange: @MainActor ([MicrocycleSetTargets]) -> Void
    /// The exercise as the editor held it: its base targets and its name.
    private let exercise: WorkoutTemplateExercise

    /// Sorted by week.
    private(set) var variations: [Variation]

    init(interactor: MicrocycleVariationsInteractor, router: MicrocycleVariationsRouter, delegate: MicrocycleVariationsDelegate) {
        self.interactor = interactor
        self.router = router
        self.onChange = delegate.onChange
        self.exercise = delegate.exercise
        self.variations = delegate.exercise.setTargetsByMicrocycle
            .sorted { $0.fromMicrocycle < $1.fromMicrocycle }
            .map { Variation(id: UUID().uuidString, fromMicrocycle: $0.fromMicrocycle, setTargets: $0.setTargets) }
    }

    var exerciseName: String { exercise.exercise.name }

    var overrides: [MicrocycleSetTargets] {
        variations.map { MicrocycleSetTargets(fromMicrocycle: $0.fromMicrocycle, setTargets: $0.setTargets) }
    }

    /// "Week 1: 2 sets · From week 2: 3 sets", or that nothing varies.
    var summary: String {
        SetTargetPlan.variationSummary(base: exercise.setTargets, overrides: overrides) ?? String(localized: "Same every week")
    }

    func weekTitle(_ variation: Variation) -> String {
        String(localized: "From week \(variation.fromMicrocycle)")
    }

    func setsTitle(_ variation: Variation) -> String {
        Format.sets(Double(variation.setTargets.count))
    }

    // MARK: - Adding

    /// The week after the last variation (week 2 for the first); when that is past the range, the
    /// first week still free. Nil when every week is taken.
    var nextWeek: Int? {
        let candidate = max(Self.weekRange.lowerBound, (variations.map(\.fromMicrocycle).max() ?? 1) + 1)
        if Self.weekRange.contains(candidate) { return candidate }
        let taken = Set(variations.map(\.fromMicrocycle))
        return Self.weekRange.first { !taken.contains($0) }
    }

    var canAddVariation: Bool { nextWeek != nil }

    /// Starts from the targets of the week before it, as fresh sets, so it begins as "the same, from
    /// here" and only what is changed differs.
    func onAddVariationPressed() {
        guard let week = nextWeek else { return }
        var lookup = exercise
        lookup.setTargetsByMicrocycle = overrides
        let seed = lookup.setTargets(forMicrocycle: week - 1).map { target in
            var copy = target
            copy.id = UUID().uuidString
            return copy
        }
        variations.append(Variation(id: UUID().uuidString, fromMicrocycle: week, setTargets: seed))
        commit()
        interactor.trackEvent(event: Event.addVariation(week: week))
    }

    // MARK: - Week

    /// A step onto a week another variation already starts on is refused; the stepper disables it.
    func canStep(_ variation: Variation, by delta: Int) -> Bool {
        let week = variation.fromMicrocycle + delta
        return Self.weekRange.contains(week) && !variations.contains { $0.id != variation.id && $0.fromMicrocycle == week }
    }

    func onStep(_ variation: Variation, by delta: Int) {
        guard canStep(variation, by: delta), let index = variations.firstIndex(where: { $0.id == variation.id }) else { return }
        variations[index].fromMicrocycle += delta
        commit()
        interactor.playHaptic(option: .selection)
    }

    // MARK: - Editing and deleting

    func onVariationPressed(_ variation: Variation) {
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: targetsBinding(for: variation.id), scope: .week(variation.fromMicrocycle)))
    }

    func onDeletePressed(_ variation: Variation) {
        variations.removeAll { $0.id == variation.id }
        commit()
    }

    /// The editor reads the exercise with this week's targets in place of the base, and writes back
    /// only the targets, to this variation by its id.
    func targetsBinding(for id: String) -> Binding<WorkoutTemplateExercise> {
        let fallback = exercise
        return Binding(
            get: { [weak self] in
                guard let self, let variation = self.variations.first(where: { $0.id == id }) else { return fallback }
                var exercise = self.exercise
                exercise.setTargets = variation.setTargets
                exercise.setTargetsByMicrocycle = []
                return exercise
            },
            set: { [weak self] newValue in
                guard let self, let index = self.variations.firstIndex(where: { $0.id == id }) else { return }
                self.variations[index].setTargets = newValue.setTargets
                self.commit()
            }
        )
    }

    // MARK: - Lifecycle

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    private func commit() {
        variations.sort { $0.fromMicrocycle < $1.fromMicrocycle }
        onChange(overrides)
    }
}

extension MicrocycleVariationsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case addVariation(week: Int)

        var eventName: String {
            switch self {
            case .onAppear: return "MicrocycleVariationsView_Appear"
            case .addVariation: return "MicrocycleVariationsView_AddVariation"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear: return nil
            case .addVariation(let week): return ["week": week]
            }
        }

        var type: LogType { .analytic }
    }
}
