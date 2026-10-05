//
//  ReminderOfferFlow.swift
//  Compound
//
//  Meal reminders and the streak reminder are off until chosen. Each is offered once, in the app,
//  at the moment it becomes relevant: meal reminders on the first visit to Nutrition, the streak
//  reminder once a two-week streak is reached. Either answer is final; the switches in Notification
//  Settings change it afterwards.
//

import SwiftUI

@MainActor
protocol ReminderOfferInteractor: GlobalInteractor {
    var privateUserSettings: PrivateUserSettings { get }
    var weeklyStreak: WeeklyStreak { get }
    func canRequestNotificationAuthorisation() async -> Bool
    func requestPushAuthorisation() async throws -> Bool
    func setMealReminders(isEnabled: Bool) async throws
    func setStreakReminder(isEnabled: Bool) async throws
}

extension CoreInteractor: ReminderOfferInteractor { }

@MainActor
final class ReminderOfferFlow {

    enum Offer: String {
        case mealReminders = "meal_reminders"
        case streakReminder = "streak_reminder"

        /// Set when the offer is shown, so it is shown once on this device whatever happens next.
        var shownKey: String { "hasShownReminderOffer_\(rawValue)" }
    }

    /// Two weeks: one is only this week's goal; a second means the habit has started to hold, and
    /// there is now a streak worth an evening reminder.
    static let streakThreshold = 2

    private let interactor: ReminderOfferInteractor
    private let router: GlobalRouter
    private let defaults: UserDefaults

    init(interactor: ReminderOfferInteractor, router: GlobalRouter, defaults: UserDefaults = .standard) {
        self.interactor = interactor
        self.router = router
        self.defaults = defaults
    }

    /// Unanswered in the private settings (on any device) and not yet shown on this one.
    /// ponytail: a second device that has not received the settings document yet can offer again.
    func shouldOffer(_ offer: Offer) -> Bool {
        guard !defaults.bool(forKey: offer.shownKey) else { return false }
        let settings = interactor.privateUserSettings
        switch offer {
        case .mealReminders:
            return settings.pushMealReminders == nil
        case .streakReminder:
            return settings.socialPushStreakReminder == nil
                && interactor.weeklyStreak.weeks >= Self.streakThreshold
        }
    }

    /// For Nutrition's appear.
    func offerMealRemindersIfNeeded() {
        present(.mealReminders)
    }

    /// For wherever the streak is seen to have grown.
    func offerStreakReminderIfNeeded() {
        present(.streakReminder)
    }

    private func present(_ offer: Offer) {
        guard shouldOffer(offer) else { return }
        defaults.set(true, forKey: offer.shownKey)
        interactor.trackEvent(event: Event.shown(offer: offer))
        let copy = copy(for: offer)
        router.showConfirmationDialog(title: copy.title, subtitle: copy.message) {
            AnyView(VStack {
                Button(copy.accept) {
                    Task { await self.answer(offer, accepted: true) }
                }
                Button("Not Now", role: .cancel) {
                    Task { await self.answer(offer, accepted: false) }
                }
            })
        }
    }

    private struct Copy {
        let title: String
        let message: String
        let accept: String
    }

    private func copy(for offer: Offer) -> Copy {
        switch offer {
        case .mealReminders:
            return Copy(
                title: String(localized: "Meal Reminders"),
                message: String(localized: "Compound can remind you to log breakfast, lunch and dinner each day. You can change this in Notification Settings."),
                accept: String(localized: "Turn On Meal Reminders")
            )
        case .streakReminder:
            let weeks = interactor.weeklyStreak.weeks
            return Copy(
                title: String(localized: "Streak Reminder"),
                message: String(localized: "You're on a \(weeks)-week streak. Compound can remind you in the evening when this week's goal needs a session that day."),
                accept: String(localized: "Turn On Streak Reminder")
            )
        }
    }

    /// Either answer is written, so the offer is not made again on another device. Saying yes asks
    /// for notification permission first when it has never been asked.
    func answer(_ offer: Offer, accepted: Bool) async {
        interactor.trackEvent(event: Event.answered(offer: offer, accepted: accepted))
        if accepted, await interactor.canRequestNotificationAuthorisation() {
            do {
                _ = try await interactor.requestPushAuthorisation()
            } catch {
                interactor.trackEvent(event: Event.requestPermissionFail(offer: offer, error: error))
            }
        }
        interactor.trackEvent(event: Event.saveStart(offer: offer, accepted: accepted))
        do {
            switch offer {
            case .mealReminders: try await interactor.setMealReminders(isEnabled: accepted)
            case .streakReminder: try await interactor.setStreakReminder(isEnabled: accepted)
            }
            interactor.trackEvent(event: Event.saveSuccess(offer: offer, accepted: accepted))
        } catch {
            interactor.trackEvent(event: Event.saveFail(offer: offer, error: error))
            router.showAlert(title: String(localized: "Unable to Save Setting"), error: error)
        }
    }

    enum Event: LoggableEvent {
        case shown(offer: Offer)
        case answered(offer: Offer, accepted: Bool)
        case requestPermissionFail(offer: Offer, error: Error)
        case saveStart(offer: Offer, accepted: Bool)
        case saveSuccess(offer: Offer, accepted: Bool)
        case saveFail(offer: Offer, error: Error)

        var eventName: String {
            switch self {
            case .shown: return "ReminderOffer_Shown"
            case .answered: return "ReminderOffer_Answered"
            case .requestPermissionFail: return "ReminderOffer_RequestPermission_Fail"
            case .saveStart: return "ReminderOffer_Save_Start"
            case .saveSuccess: return "ReminderOffer_Save_Success"
            case .saveFail: return "ReminderOffer_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .shown(let offer): return ["offer": offer.rawValue]
            case .answered(let offer, let accepted), .saveStart(let offer, let accepted), .saveSuccess(let offer, let accepted):
                return ["offer": offer.rawValue, "accepted": accepted]
            case .requestPermissionFail(let offer, let error), .saveFail(let offer, let error):
                return error.eventParameters.merging(["offer": offer.rawValue]) { current, _ in current }
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            case .requestPermissionFail: return .warning
            default: return .analytic
            }
        }
    }
}
