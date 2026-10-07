import SwiftUI

/// One set's plan in the template editor (Workout Settings › Set Plan): its kind, and the drops,
/// mini-sets, AMRAP target, partial reps or hold time that kind takes. Every change goes straight
/// back to the editor's working copy, so the editor's own Save and Cancel still decide whether any
/// of it is kept.
@Observable
@MainActor
class SetPlanDetailPresenter {

    private let interactor: SetTargetInteractor
    private let router: SetTargetRouter
    private let onChange: @MainActor (SetTarget) -> Void

    private(set) var setTarget: SetTarget

    init(interactor: SetTargetInteractor, router: SetTargetRouter, delegate: SetPlanDetailDelegate) {
        self.interactor = interactor
        self.router = router
        self.onChange = delegate.onChange
        self.setTarget = delegate.setTarget
    }

    let kinds = SetTargetPlan.kinds
    let dropSteps = SetTargetPlan.dropSteps
    let dropCountRange = SetTargetPlan.dropCountRange
    let miniSetCountRange = SetTargetPlan.miniSetCountRange
    /// With the set's own value among them, so an imported 40 s hold still shows.
    var holdSecondsChoices: [Int] { Set(SetTargetPlan.holdSecondsChoices + [holdSeconds]).sorted() }
    /// To failure first, then the counts, the set's own among them.
    var partialRepsChoices: [Int?] { [nil] + Set(Array(SetTargetPlan.partialRepsRange) + [partialReps].compactMap { $0 }).sorted().map(Optional.some) }

    var title: String { String(localized: "Set \(setTarget.setNumber)") }
    var setTypeAccessibilityLabel: String { String(localized: "Set \(setTarget.setNumber), set type") }

    func kindTitle(_ type: SetTargetSetType) -> String { SetTargetPlan.title(for: type) }
    func dropStepTitle(_ percent: Int) -> String { SetTargetPlan.dropStepTitle(percent) }

    // MARK: - Kind

    /// A failure set from before AMRAP existed shows as AMRAP.
    var setType: SetTargetSetType {
        get { setTarget.setType == .failure ? .amrap : setTarget.setType }
        set {
            guard newValue != setType else { return }
            update { target in
                target.setType = newValue
                // A kind arrives with a plan to start from, so the summary under the set and the
                // session made from it agree from the first tap.
                switch newValue {
                case .drop: target.dropCount = target.dropCount ?? 2
                case .myo, .restPause, .cluster: target.miniSetCount = target.miniSetCount ?? 3
                case .amrap, .failure: target.amrapTargetReps = target.amrapTargetReps ?? target.minReps ?? target.maxReps
                case .stretch, .hold: target.holdSeconds = target.holdSeconds ?? Self.defaultHoldSeconds
                case .standard, .partials: break
                }
            }
            interactor.playHaptic(option: .selection)
        }
    }

    var showsDrops: Bool { setType == .drop }
    var showsMiniSets: Bool { [.myo, .restPause, .cluster].contains(setType) }
    var showsAMRAPTarget: Bool { setType == .amrap }
    var showsPartialReps: Bool { setType == .partials }
    var showsHoldSeconds: Bool { setType == .stretch || setType == .hold }

    // MARK: - Drop

    var dropCount: Int {
        get { setTarget.dropCount ?? 0 }
        set { update { $0.dropCount = newValue } }
    }

    var dropCountTitle: String { String(localized: "\(dropCount) drops") }

    var dropStep: Int { setTarget.dropStep }

    func onDropStepPressed(_ percent: Int) {
        guard percent != dropStep else { return }
        update { $0.dropStepPercent = percent }
        interactor.playHaptic(option: .selection)
    }

    /// The reps each drop asks for; an empty field is to failure.
    var dropReps: Double? {
        get { setTarget.dropReps.map(Double.init) }
        set { update { $0.dropReps = Self.reps(newValue) } }
    }

    // MARK: - Mini-sets

    var miniSetCount: Int {
        get { setTarget.miniSetCount ?? 0 }
        set { update { $0.miniSetCount = newValue } }
    }

    var miniSetCountTitle: String { String(localized: "\(miniSetCount) mini-sets") }

    // MARK: - AMRAP

    var amrapTargetReps: Double? {
        get { setTarget.amrapTargetReps.map(Double.init) }
        set { update { $0.amrapTargetReps = Self.reps(newValue) } }
    }

    // MARK: - Partials

    /// The partial reps after the set; nil is to failure.
    var partialReps: Int? {
        get { setTarget.partialReps }
        set { update { $0.partialReps = newValue } }
    }

    func partialRepsTitle(_ reps: Int?) -> String {
        reps.map { Format.reps($0) } ?? String(localized: "To failure")
    }

    // MARK: - Stretch and hold

    static let defaultHoldSeconds = 30

    var holdSeconds: Int {
        get { setTarget.holdSeconds ?? Self.defaultHoldSeconds }
        set { update { $0.holdSeconds = newValue } }
    }

    func holdSecondsTitle(_ seconds: Int) -> String { String(localized: "\(seconds) s") }

    // MARK: - Lifecycle

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onDonePressed() {
        router.dismissScreen()
    }

    // MARK: - Private

    /// Writes `amrap` for a legacy failure set on its first edit.
    private func update(_ change: (inout SetTarget) -> Void) {
        change(&setTarget)
        if setTarget.setType == .failure {
            setTarget.setType = .amrap
        }
        onChange(setTarget)
    }

    /// A typed count of reps: whole, at least one, or none.
    private static func reps(_ value: Double?) -> Int? {
        guard let value, value.isFinite, value >= 1, value <= 999 else { return nil }
        return Int(value.rounded())
    }
}

extension SetPlanDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear

        var eventName: String {
            switch self {
            case .onAppear: return "SetPlanDetailView_Appear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
