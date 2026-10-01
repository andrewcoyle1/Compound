//
//  PushManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import UserNotifications
@testable import Compound

/// Local notifications: the re-engagement week and the three meal reminders.
///
/// Most of this manager is a thin call into `LocalNotifications` or straight into
/// `UNUserNotificationCenter.current()`, neither of which is injected, so a unit test cannot reach
/// them without actually scheduling on the machine running the tests. That rules out asserting on:
///
/// - `checkPushNotificationAuthorisation`, `requestAuthorisation` and `canRequestAuthorisation`,
///   which read or raise the system permission prompt;
/// - `scheduleComeBackReminders`, `schedulePushNotification` and
///   `setMealReminders`, which register real requests with the notification
///   centre — calling any of them from a test would leave three to six notifications pending on
///   the simulator, and the success and failure events they log are only reachable through that;
/// - `removeDeliveredNotifications`, `clearAllDeliveredNotifications` and
///   `cancelMealReminderNotifications`, which mutate the same centre and return nothing.
///
/// What is left, and what this covers, is the data those calls are built from: the reminder
/// identifiers, the day offsets the week is laid out on, the delegate a caller fills in, and the
/// events. Each of those is the part that can be wrong without crashing — a renamed identifier
/// stops a reminder ever being cancelled, and a renamed event silently empties a funnel.
@MainActor
struct PushManagerTests {

    // MARK: - Meal reminder identifiers

    /// `scheduleMealReminderNotifications` and `cancelMealReminderNotifications` both work from
    /// this one list, and cancelling is by identifier. A reminder scheduled under a name that is
    /// no longer in the list repeats daily with nothing able to turn it off, so these three
    /// strings are effectively permanent.
    @Test("Test The Meal Reminder Identifiers Are The Three Stored Names")
    func testTheMealReminderIdentifiersAreTheThreeStoredNames() {
        #expect(PushManager.mealReminderIDs == [
            "meal_reminder_breakfast",
            "meal_reminder_lunch",
            "meal_reminder_dinner"
        ])
    }

    /// Two reminders sharing an identifier would leave only one scheduled — the notification
    /// centre keys pending requests by id.
    @Test("Test The Meal Reminder Identifiers Are Distinct")
    func testTheMealReminderIdentifiersAreDistinct() {
        #expect(Set(PushManager.mealReminderIDs).count == PushManager.mealReminderIDs.count)
    }

    // MARK: - The come-back reminders

    /// Changed: the week used to be scheduled under random ids after clearing everything pending,
    /// which also withdrew the meal reminders and the rest-over alert. The three reminders now have
    /// fixed ids, so the switch can withdraw exactly them, and land one, three and five days out.
    @Test("Test The Come Back Reminders Land One Three And Five Days Out Under Fixed Ids")
    func testTheComeBackRemindersLandOneThreeAndFiveDaysOut() throws {
        let requests = PushManager.comeBackReminderRequests()

        #expect(requests.map(\.identifier) == PushManager.comeBackReminderIDs)
        let intervals = try requests.map { try #require($0.trigger as? UNTimeIntervalNotificationTrigger).timeInterval }
        #expect(intervals == [86_400, 3 * 86_400, 5 * 86_400])
        let titles = requests.map(\.content.title)
        #expect(titles.allSatisfy { !$0.contains("!") })
    }

    /// Anything pending that this version does not know was left by an older one and is withdrawn;
    /// what it does know has to survive that sweep.
    @Test("Test The Known Pending Ids Cover Every Local Notification")
    func testTheKnownPendingIdsCoverEveryLocalNotification() {
        let known = PushManager.knownPendingIDs
        #expect(known.isSuperset(of: PushManager.comeBackReminderIDs))
        #expect(known.isSuperset(of: PushManager.mealReminderIDs))
        #expect(known.contains(RestOverNotification.id))
    }

    // MARK: - Meal reminders

    @Test("Test Meal Reminders Are Passive Daily Reminders At Meal Times")
    func testMealRemindersArePassiveDailyReminders() throws {
        let requests = PushManager.mealReminderRequests()

        #expect(requests.map(\.identifier) == PushManager.mealReminderIDs)
        let levels = requests.map(\.content.interruptionLevel)
        #expect(levels == [.passive, .passive, .passive])
        let triggers = try requests.map { try #require($0.trigger as? UNCalendarNotificationTrigger) }
        let hours = triggers.map(\.dateComponents.hour)
        #expect(hours == [8, 12, 18])
        let allRepeat = triggers.allSatisfy { $0.repeats }
        #expect(allRepeat)
    }

    // MARK: - Foreground presentation

    /// Social activity already shows in the app, so it goes to Notification Center quietly; the
    /// rest-over alert shows nothing (the tracker has its own); anything else keeps its banner.
    @Test("Test Social Pushes Go Quietly To The List While The App Is In Front")
    func testForegroundPresentation() {
        for type in ["like", "comment", "mention", "follow", "followAccepted", "follow_request", "nudge", "share", "challenge_complete"] {
            #expect(PushManager.foregroundPresentation(identifier: "x", type: type) == [.list, .badge])
        }
        #expect(PushManager.foregroundPresentation(identifier: RestOverNotification.id, type: nil) == [])
        #expect(PushManager.foregroundPresentation(identifier: "x", type: "streakReminder") == [.banner, .sound, .badge])
        #expect(PushManager.foregroundPresentation(identifier: "x", type: nil) == [.banner, .sound, .badge])
    }

    /// The server's catalog keys have to format to the English `functions/lib.js` sends beside them.
    @Test("Test The Server's Push Copy Formats As The Server Writes It")
    func testRemotePushCopyMatchesTheServer() {
        let entries = RemotePushCopy.catalogEntries("Jane", "Hi")
        #expect(entries.contains("Jane replied to your comment: \"Hi\""))
        #expect(entries.contains("Jane wants to follow you"))
        #expect(entries.contains("Workouts this week: you Jane, your circle Hi."))
    }

    /// A day is added as a fixed 86,400 seconds rather than as a calendar day, so the three
    /// reminders land at the same clock time only while the offset does not cross a clock change.
    /// Pinned because the behaviour is deliberate — the reminders are relative to the last session,
    /// not to a time of day — and an hour of drift across a DST boundary is acceptable where a
    /// silently missing reminder would not be.
    @Test("Test A Day Offset Is A Fixed Twenty Four Hours")
    func testADayOffsetIsAFixedTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(now.addingTimeInterval(days: 1).timeIntervalSince(now) == 86_400)
        #expect(now.addingTimeInterval(days: 3).timeIntervalSince(now) == 3 * 86_400)
        #expect(now.addingTimeInterval(days: 5).timeIntervalSince(now) == 5 * 86_400)
    }

    // MARK: - The delegate a caller fills in

    /// The only content a caller supplies. Its defaults are what every call site that omits them
    /// gets: a sound, no badge, and a notification that fires once.
    @Test("Test A Notification Delegate Defaults To A One Off Sounding Notification")
    func testANotificationDelegateDefaultsToAOneOffSoundingNotification() {
        let triggerDate = Date(timeIntervalSince1970: 1_700_000_000)

        let delegate = PushNotificationDelegate(
            identifier: "rest-timer",
            title: "Rest over",
            subtitle: "Back to it.",
            triggerDate: triggerDate
        )

        #expect(delegate.identifier == "rest-timer")
        #expect(delegate.title == "Rest over")
        #expect(delegate.subtitle == "Back to it.")
        #expect(delegate.triggerDate == triggerDate)
        #expect(delegate.sound)
        #expect(delegate.badge == nil)
        #expect(delegate.repeats == false)
        #expect(delegate.interruptionLevel == .active)
        #expect(delegate.content.sound != nil)
    }

    /// "Rest Complete" is Time Sensitive, and with "Play Sound" off it is still delivered: a banner
    /// with no sound, so a locked phone still shows the rest ended.
    @Test("Test A Silent Time Sensitive Notification Keeps Its Banner And Drops Its Sound")
    func testASilentTimeSensitiveNotification() {
        let delegate = PushNotificationDelegate(
            identifier: RestOverNotification.id,
            title: "Rest Complete",
            subtitle: "Next: Squat",
            triggerDate: Date(timeIntervalSince1970: 1_700_000_000),
            sound: false,
            interruptionLevel: .timeSensitive
        )

        let content = delegate.content
        #expect(content.sound == nil)
        #expect(content.title == "Rest Complete")
        #expect(content.body == "Next: Squat")
        #expect(content.interruptionLevel == .timeSensitive)
    }

    /// A repeating notification with a badge is the other shape in use. `AnyNotificationContent`,
    /// which `schedulePushNotification` maps these onto, keeps its properties internal to its own
    /// package, so the mapping itself cannot be read back from here — only the values handed to it.
    @Test("Test A Notification Delegate Carries Every Value It Was Given")
    func testANotificationDelegateCarriesEveryValueItWasGiven() {
        let triggerDate = Date(timeIntervalSince1970: 1_700_000_000)

        let delegate = PushNotificationDelegate(
            identifier: "daily-weigh-in",
            title: "Weigh in",
            subtitle: "Same time each morning.",
            triggerDate: triggerDate,
            sound: false,
            badge: 2,
            repeats: true
        )

        #expect(delegate.sound == false)
        #expect(delegate.badge == 2)
        #expect(delegate.repeats)
    }

    // MARK: - Authorisation state

    /// The manager reports not-determined until something asks the system, and nothing about
    /// building it asks. Screens gate the "turn on notifications" prompt on this, so a manager
    /// that claimed to be authorised before checking would hide the prompt from a user who had
    /// never been asked.
    @Test("Test Authorisation Is Undetermined Until Something Checks")
    func testAuthorisationIsUndeterminedUntilSomethingChecks() {
        #expect(TestManagers.pushManager().isAuthorised == .notDetermined)
        #expect(TestManagers.pushManager(logManager: LogManager(services: [])).isAuthorised == .notDetermined)
    }

    // MARK: - Events

    /// These three strings are the column names in the analytics warehouse. A failed week is
    /// `.severe` because it means a user who stopped opening the app will not be reminded to —
    /// the one case where the absence of a notification is invisible from the app itself.
    @Test("Test The Push Events Keep Their Names And Severities")
    func testThePushEventsKeepTheirNamesAndSeverities() {
        let success = PushManager.Event.weekScheduledSuccess
        let failure = PushManager.Event.weekScheduledFail(error: URLError(.notConnectedToInternet))
        let reminders = PushManager.Event.mealRemindersScheduled

        #expect(success.eventName == "PushMan_WeekScheduled_Success")
        #expect(failure.eventName == "PushMan_WeekScheduled_Fail")
        #expect(reminders.eventName == "PushMan_MealReminders_Scheduled")

        #expect(success.type == .analytic)
        #expect(reminders.type == .analytic)
        #expect(failure.type == .severe)
    }

    /// The failure event is the only trace an unscheduled week leaves, so it has to carry enough
    /// to tell one cause from another rather than only that something went wrong.
    @Test("Test A Failed Week Reports What Went Wrong")
    func testAFailedWeekReportsWhatWentWrong() throws {
        let event = PushManager.Event.weekScheduledFail(error: URLError(.notConnectedToInternet))

        let parameters = try #require(event.parameters)
        #expect(parameters["error_domain"] as? String == URLError.errorDomain)
        #expect(parameters["error_code"] as? Int == URLError.Code.notConnectedToInternet.rawValue)
        #expect(parameters["error_description"] != nil)
    }

    /// The two events that cannot fail carry nothing, so the warehouse does not grow columns for
    /// parameters that are always absent.
    @Test("Test The Succeeding Events Carry No Parameters")
    func testTheSucceedingEventsCarryNoParameters() {
        #expect(PushManager.Event.weekScheduledSuccess.parameters == nil)
        #expect(PushManager.Event.mealRemindersScheduled.parameters == nil)
    }
}
