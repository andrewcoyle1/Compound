//
//  ReminderOfferFlowTests.swift
//  CompoundUnitTests
//
//  Meal reminders and the streak reminder are off until chosen, and each is offered once.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
struct ReminderOfferFlowTests {

    private final class Interactor: SpyGlobalInteractor, ReminderOfferInteractor {
        var privateUserSettings = PrivateUserSettings()
        var weeklyStreak = WeeklyStreak.fixture(weeks: 0)
        var canRequest = true
        private(set) var requestCount = 0
        private(set) var mealWrites: [Bool] = []
        private(set) var streakWrites: [Bool] = []

        func canRequestNotificationAuthorisation() async -> Bool { canRequest }

        func requestPushAuthorisation() async throws -> Bool {
            requestCount += 1
            canRequest = false
            return true
        }

        func setMealReminders(isEnabled: Bool) async throws {
            mealWrites.append(isEnabled)
            privateUserSettings.pushMealReminders = isEnabled
        }

        func setStreakReminder(isEnabled: Bool) async throws {
            streakWrites.append(isEnabled)
            privateUserSettings.socialPushStreakReminder = isEnabled
        }
    }

    private final class Router: GlobalRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var dialogTitles: [String] = []

        func showAlert(error: Error) { }
        func showAlert(title: String, error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            dialogTitles.append(title)
        }
    }

    private struct Screen {
        let flow: ReminderOfferFlow
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        // A throwaway suite, so "shown once" does not leak between tests or into the app.
        let defaults = UserDefaults(suiteName: "ReminderOfferFlowTests-\(UUID().uuidString)") ?? .standard
        return Screen(flow: ReminderOfferFlow(interactor: interactor, router: router, defaults: defaults), interactor: interactor, router: router)
    }

    // MARK: - Meal reminders

    @Test("Test Meal Reminders Are Offered Once, On The First Visit")
    func testMealRemindersAreOfferedOnce() {
        let screen = makeScreen()

        screen.flow.offerMealRemindersIfNeeded()
        screen.flow.offerMealRemindersIfNeeded()

        #expect(screen.router.dialogTitles == ["Meal Reminders"])
        #expect(screen.interactor.trackedEventNames == ["ReminderOffer_Shown"])
    }

    @Test("Test Meal Reminders Are Not Offered Once Answered On Any Device")
    func testMealRemindersAreNotOfferedOnceAnswered() {
        let screen = makeScreen()
        screen.interactor.privateUserSettings.pushMealReminders = false

        screen.flow.offerMealRemindersIfNeeded()

        #expect(screen.router.dialogTitles.isEmpty)
    }

    @Test("Test Accepting Meal Reminders Asks For Permission Then Turns Them On")
    func testAcceptingMealReminders() async {
        let screen = makeScreen()

        await screen.flow.answer(.mealReminders, accepted: true)

        #expect(screen.interactor.requestCount == 1)
        #expect(screen.interactor.mealWrites == [true])
        #expect(screen.interactor.privateUserSettings.isMealRemindersEnabled)
        #expect(!screen.flow.shouldOffer(.mealReminders))
    }

    @Test("Test Not Now Records The Answer And Asks For Nothing")
    func testDecliningMealReminders() async {
        let screen = makeScreen()

        await screen.flow.answer(.mealReminders, accepted: false)

        #expect(screen.interactor.requestCount == 0)
        #expect(screen.interactor.mealWrites == [false])
        #expect(!screen.interactor.privateUserSettings.isMealRemindersEnabled)
        #expect(!screen.flow.shouldOffer(.mealReminders))
    }

    // MARK: - Streak reminder

    /// One week is only this week's goal; the offer waits for a second.
    @Test("Test The Streak Reminder Waits For A Two Week Streak")
    func testTheStreakReminderWaitsForATwoWeekStreak() {
        let screen = makeScreen()

        screen.interactor.weeklyStreak = .fixture(weeks: 1)
        screen.flow.offerStreakReminderIfNeeded()
        #expect(screen.router.dialogTitles.isEmpty)

        screen.interactor.weeklyStreak = .fixture(weeks: 2)
        screen.flow.offerStreakReminderIfNeeded()
        screen.flow.offerStreakReminderIfNeeded()
        #expect(screen.router.dialogTitles == ["Streak Reminder"])
    }

    @Test("Test Accepting The Streak Reminder Turns On The Server's Switch")
    func testAcceptingTheStreakReminder() async {
        let screen = makeScreen()

        await screen.flow.answer(.streakReminder, accepted: true)

        #expect(screen.interactor.streakWrites == [true])
        #expect(screen.interactor.privateUserSettings.isStreakReminderEnabled)
        #expect(screen.interactor.trackedEventNames == ["ReminderOffer_Answered", "ReminderOffer_Save_Start", "ReminderOffer_Save_Success"])
    }

    // MARK: - Defaults

    /// Absent fields are what every existing account has: come-back on, meals and streak off.
    @Test("Test Absent Settings Read As Come Back On And Meals And Streak Off")
    func testDefaults() {
        let settings = PrivateUserSettings()
        #expect(settings.isComeBackRemindersEnabled)
        #expect(!settings.isMealRemindersEnabled)
        #expect(!settings.isStreakReminderEnabled)
    }
}
