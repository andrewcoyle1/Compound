import SwiftUI

struct MealItemContributor: Identifiable {
    var id: String { displayName }
    let displayName: String
    let calories: Double
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
}

@Observable
@MainActor
class NutritionOverviewPresenter {

    private let interactor: NutritionOverviewInteractor
    private let router: NutritionOverviewRouter

    var showsContributors: Bool = false
    private var dayKey: String = ""

    private(set) var totals: DailyMacroTarget = DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
    private(set) var target: DailyMacroTarget?
    private(set) var breakdown: DailyNutritionBreakdown = .empty

    /// The pending suggestion that the calorie target should move, or nil when there is none.
    ///
    /// Held rather than read through to the interactor so accepting or dismissing takes the card
    /// off the screen in the same frame, instead of waiting for the plan to come back from
    /// Firestore.
    private(set) var proposal: TargetProposal?
    private(set) var isApplyingProposal: Bool = false

    /// Whether this week's check-in is waiting, and for which week.
    ///
    /// Held for the same reason as `proposal`: starting or skipping has to take the card off the
    /// screen now, not once Firestore has agreed.
    private(set) var checkInState: CheckInState = .notDue

    init(interactor: NutritionOverviewInteractor, router: NutritionOverviewRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: NutritionOverviewDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        loadData(delegate: delegate)
    }

    func onViewDisappear(delegate: NutritionOverviewDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    private func loadData(delegate: NutritionOverviewDelegate) {
        let dayKey = delegate.dayKey
        self.dayKey = dayKey
        proposal = interactor.targetProposal
        checkInState = interactor.checkInState
        // Silent: local reads on appear; the previous or empty value is the right fallback.
        totals = (try? interactor.getDailyTotals(dayKey: dayKey)) ?? totals
        breakdown = (try? interactor.getDailyNutritionBreakdown(dayKey: dayKey)) ?? .empty
        guard let userId = interactor.userId else { return }
        let date = Date(dayKey: dayKey) ?? Date()
        Task {
            // Silent: background read; the rings show no target until one loads.
            target = try? await interactor.getDailyTarget(for: date, userId: userId)
        }
    }

    // MARK: Weekly check-in

    /// The week the card is offering, or nil when no check-in is due.
    ///
    /// The card takes the proposal card's place while it is showing rather than sitting above it:
    /// the proposal is the last step of the check-in, and offering it twice on one screen invites
    /// the user to accept it outside the flow that was meant to explain it.
    var dueCheckInWeekStart: Date? {
        guard case .due(let weekStart) = checkInState else { return nil }
        return weekStart
    }

    func onStartCheckInPressed() {
        guard let weekStart = dueCheckInWeekStart else { return }
        interactor.trackEvent(event: Event.checkInStarted(weekStart: weekStart))
        router.showCheckInView(delegate: CheckInDelegate(weekStart: weekStart))
    }

    /// Skipping is optimistic, and puts the card back if the write does not land — the same shape
    /// as accepting a proposal, and for the same reason: a card that vanished on a failed write
    /// would look exactly like a week that had been dealt with.
    func onSkipCheckInPressed() {
        guard let weekStart = dueCheckInWeekStart else { return }
        interactor.trackEvent(event: Event.checkInSkipped(weekStart: weekStart))
        checkInState = .notDue
        Task {
            do {
                try await interactor.markCheckInSkipped(weekStart: weekStart)
            } catch {
                checkInState = .due(weekStart: weekStart)
                router.showAlert(error: error)
            }
        }
    }

    // MARK: Target proposal

    /// "2,180 kcal a day, up from 2,050" — the whole of what the card has to say.
    var proposalSummary: String? {
        guard let proposal else { return nil }
        let direction = proposal.proposedTargetKcal > proposal.currentTargetKcal ? String(localized: "up from") : String(localized: "down from")
        return String(localized: "\(String(describing: Int(proposal.proposedTargetKcal))) kcal a day, \(direction) \(String(describing: Int(proposal.currentTargetKcal))).")
    }

    /// Takes the card away optimistically, and puts it back if the save does not land.
    ///
    /// Swallowing the error would leave the user with no card and an unchanged plan — the one
    /// outcome that looks exactly like success and is not. The card coming back, with the alert
    /// next to it, is what makes a failed accept retryable.
    func onAcceptProposalPressed() {
        guard !isApplyingProposal, let accepted = proposal else { return }
        interactor.trackEvent(event: Event.proposalAccepted(proposal: accepted))
        isApplyingProposal = true
        proposal = nil
        Task {
            do {
                try await interactor.acceptTargetProposal()
            } catch {
                proposal = accepted
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.proposalAcceptFailed(error: error))
            }
            isApplyingProposal = false
        }
    }

    func onDismissProposalPressed() {
        guard let dismissed = proposal else { return }
        interactor.trackEvent(event: Event.proposalDismissed(proposal: dismissed))
        interactor.dismissTargetProposal()
        proposal = nil
    }

    // MARK: Progress helpers (0–1)

    var caloriesProgress: Double {
        guard let targetCal = target?.calories, targetCal > 0 else { return 0 }
        return min(totals.calories / targetCal, 1)
    }

    var proteinProgress: Double {
        guard let proteinTarget = target?.proteinGrams, proteinTarget > 0 else { return 0 }
        return min(totals.proteinGrams / proteinTarget, 1)
    }

    var carbsProgress: Double {
        guard let carbTarget = target?.carbGrams, carbTarget > 0 else { return 0 }
        return min(totals.carbGrams / carbTarget, 1)
    }

    var fatProgress: Double {
        guard let fatTarget = target?.fatGrams, fatTarget > 0 else { return 0 }
        return min(totals.fatGrams / fatTarget, 1)
    }

    var topContributors: [MealItemContributor] {
        guard showsContributors else { return [] }
        // Silent: local read for a derived list; empty hides the section.
        let meals = (try? interactor.getMeals(for: dayKey)) ?? []
        // swiftlint:disable:next large_tuple
        var totals: [String: (cal: Double, pro: Double, carb: Double, fat: Double)] = [:]
        for item in meals.flatMap(\.items) {
            let key = item.displayName
            totals[key, default: (0, 0, 0, 0)].cal  += item.calories ?? 0
            totals[key, default: (0, 0, 0, 0)].pro  += item.proteinGrams ?? 0
            totals[key, default: (0, 0, 0, 0)].carb += item.carbGrams ?? 0
            totals[key, default: (0, 0, 0, 0)].fat  += item.fatGrams ?? 0
        }
        return totals
            .map { name, vals in
                MealItemContributor(
                    displayName: name,
                    calories: vals.cal,
                    proteinGrams: vals.pro,
                    carbGrams: vals.carb,
                    fatGrams: vals.fat
                )
            }
            .sorted { $0.calories > $1.calories }
    }
}

extension NutritionOverviewPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: NutritionOverviewDelegate)
        case onDisappear(delegate: NutritionOverviewDelegate)
        case proposalAccepted(proposal: TargetProposal)
        case proposalDismissed(proposal: TargetProposal)
        case proposalAcceptFailed(error: Error)
        case checkInStarted(weekStart: Date)
        case checkInSkipped(weekStart: Date)

        var eventName: String {
            switch self {
            case .onAppear:            return "NutritionOverviewView_Appear"
            case .onDisappear:         return "NutritionOverviewView_Disappear"
            case .proposalAccepted:    return "NutritionOverviewView_Proposal_Accept"
            case .proposalDismissed:   return "NutritionOverviewView_Proposal_Dismiss"
            case .proposalAcceptFailed: return "NutritionOverviewView_Proposal_Accept_Fail"
            case .checkInStarted:      return "NutritionOverviewView_CheckIn_Start"
            case .checkInSkipped:      return "NutritionOverviewView_CheckIn_Skip"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return delegate.eventParameters
            case .proposalAccepted(let proposal), .proposalDismissed(let proposal):
                return [
                    "proposal_current_kcal": proposal.currentTargetKcal,
                    "proposal_proposed_kcal": proposal.proposedTargetKcal,
                    "proposal_expenditure_kcal": proposal.expenditureKcal,
                    "proposal_reason": proposal.reason.rawValue
                ]
            case .proposalAcceptFailed(let error):
                return ["error": error.localizedDescription]
            case .checkInStarted(let weekStart), .checkInSkipped(let weekStart):
                return ["check_in_week_start": weekStart]
            }
        }

        var type: LogType {
            switch self {
            case .proposalAcceptFailed: return .severe
            default:                    return .analytic
            }
        }
    }
}
