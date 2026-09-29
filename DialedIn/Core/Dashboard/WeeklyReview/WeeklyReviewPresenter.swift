import SwiftUI

@Observable
@MainActor
class WeeklyReviewPresenter {

    private let interactor: WeeklyReviewInteractor
    private let router: WeeklyReviewRouter
    private let calendar: Calendar
    private let now: () -> Date

    /// Any date in the week on screen. Opens on last week on the first day of a week, when this
    /// week has barely started, and on this week otherwise.
    private(set) var week: Date
    private(set) var isSharing = false

    init(
        interactor: WeeklyReviewInteractor,
        router: WeeklyReviewRouter,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
        self.now = now
        let today = now()
        self.week = CircleWeek.isFirstDayOfWeek(today, calendar: calendar)
            ? calendar.date(byAdding: .weekOfYear, value: -1, to: today) ?? today
            : today
    }

    var review: WeeklyReview {
        let user = interactor.currentUser
        return WeeklyReview.build(
            sessions: interactor.workoutSessions,
            measurements: interactor.bodyMeasurements,
            meals: interactor.userMeals,
            week: week,
            userId: user?.userId ?? "",
            goal: user.map(CircleWeek.goal(for:)) ?? CircleWeek.defaultGoal,
            templates: Dictionary(interactor.allExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            dailyTargets: interactor.currentDietPlan?.days ?? [],
            calendar: calendar
        )
    }

    var canShowNextWeek: Bool {
        !calendar.isDate(week, equalTo: now(), toGranularity: .weekOfYear)
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onPreviousWeekPressed() {
        week = calendar.date(byAdding: .weekOfYear, value: -1, to: week) ?? week
    }

    func onNextWeekPressed() {
        guard canShowNextWeek else { return }
        week = calendar.date(byAdding: .weekOfYear, value: 1, to: week) ?? week
    }

    func onClosePressed() {
        router.dismissScreen()
    }

    func onSharePressed() {
        guard !isSharing else { return }
        interactor.trackEvent(event: Event.sharePressed)
        isSharing = true
        defer { isSharing = false }
        guard let image = WeeklyReviewShareCardView.render(review) else {
            router.showSimpleAlert(title: String(localized: "Unable to create the image"), subtitle: String(localized: "Please try again."))
            return
        }
        router.showShareSheet(items: [image])
    }
}

extension WeeklyReviewPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case sharePressed

        var eventName: String {
            switch self {
            case .onAppear:     return "WeeklyReviewView_Appear"
            case .sharePressed: return "WeeklyReviewView_Share_Pressed"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
