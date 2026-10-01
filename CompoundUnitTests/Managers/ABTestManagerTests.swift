//
//  ABTestManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

private enum ABTestStubError: Error { case failed }

/// The manager that decides which variant of a test a user is in.
///
/// Two things make it worth pinning. `activeTests` is read synchronously by the paywall the first
/// time it renders, so the manager has to hold a usable answer the instant it is constructed —
/// before the remote fetch it kicks off in `init` has come back. And when that fetch fails, the
/// values already in hand have to survive: a user silently moved between variants mid-session
/// invalidates the test they were counted in.
///
/// `FirebaseABTestService` is not covered here — it reads `RemoteConfig.remoteConfig()` directly
/// and `saveUpdatedConfig` is an `assertionFailure` by design, so neither can be reached without
/// a configured Firebase app.
@MainActor
struct ABTestManagerTests {

    // MARK: - Doubles

    /// An `ABTestService` whose stored values, fetched values and failures are set independently,
    /// so the difference between "what we had" and "what the remote said" is observable.
    private final class StubService: ABTestService {
        var activeTests: ActiveABTests
        var fetched: ActiveABTests?
        var fetchError: Error?
        var saveError: Error?
        private(set) var fetchCount = 0
        private(set) var savedTests: [ActiveABTests] = []

        init(activeTests: ActiveABTests) {
            self.activeTests = activeTests
        }

        func saveUpdatedConfig(updatedTests: ActiveABTests) throws {
            if let saveError { throw saveError }
            savedTests.append(updatedTests)
            activeTests = updatedTests
        }

        func fetchUpdatedConfig() async throws -> ActiveABTests {
            fetchCount += 1
            if let fetchError { throw fetchError }
            return fetched ?? activeTests
        }
    }

    // MARK: - Reading

    /// No `await` here on purpose: the paywall reads `activeTests` during its first render, so the
    /// service's values have to be in place by the time `init` returns.
    @Test("Test Active Tests Are Available The Instant The Manager Is Built")
    func testActiveTestsAreAvailableImmediately() {
        let service = MockABTestService(notificationsTest: true, paywallTest: .storeKit)

        let manager = ABTestManager(service: service)

        #expect(manager.activeTests.notificationsTest)
        #expect(manager.activeTests.paywallTest == .storeKit)
    }

    @Test("Test An Unconfigured Service Gives The Default Variants")
    func testUnconfiguredServiceGivesTheDefaultVariants() {
        let manager = ABTestManager(service: MockABTestService())

        #expect(manager.activeTests.notificationsTest == false)
        #expect(manager.activeTests.paywallTest == .default)
    }

    /// The remote is the source of truth once it answers, so a variant that changed server-side
    /// has to replace the one the manager started with.
    @Test("Test The Remote Fetch Replaces The Starting Variants")
    func testRemoteFetchReplacesTheStartingVariants() async {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: false, paywallTest: .custom))
        service.fetched = ActiveABTests(notificationsTest: true, paywallTest: .revenueCat)

        let manager = ABTestManager(service: service)

        #expect(await TestManagers.eventually { manager.activeTests.paywallTest == .revenueCat })
        #expect(manager.activeTests.notificationsTest)
    }

    /// Offline launches take this path. Reassigning a user to a different variant because the
    /// fetch failed would mix their behaviour across two arms of the same test.
    @Test("Test A Failed Fetch Leaves The Starting Variants In Place")
    func testFailedFetchLeavesTheStartingVariantsInPlace() async {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: true, paywallTest: .storeKit))
        service.fetchError = ABTestStubError.failed

        let manager = ABTestManager(service: service)

        // Waiting on the fetch itself rather than on the values, so a fetch that never ran cannot
        // pass as a fetch that failed harmlessly.
        #expect(await TestManagers.eventually { service.fetchCount == 1 })
        #expect(manager.activeTests.paywallTest == .storeKit)
        #expect(manager.activeTests.notificationsTest)
    }

    // MARK: - Overriding

    /// The dev-tools override has to reach the service, not just the manager's copy — otherwise it
    /// is forgotten on the next launch.
    @Test("Test Overriding Writes Through To The Service And Is Read Back")
    func testOverridingWritesThroughToTheService() throws {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: false, paywallTest: .custom))
        let manager = ABTestManager(service: service)

        try manager.override(updatedTests: ActiveABTests(notificationsTest: true, paywallTest: .storeKit))

        #expect(service.savedTests.count == 1)
        #expect(service.savedTests.first?.paywallTest == .storeKit)
        // Read synchronously, because the override screen shows the new value straight away.
        #expect(manager.activeTests.paywallTest == .storeKit)
        #expect(manager.activeTests.notificationsTest)
    }

    /// The reason `override` must not re-run `configure()`. Against a service whose save and fetch
    /// can disagree — which is every real one, since Remote Config never accepts a client save —
    /// a re-fetch assigns the server's values over the override that was just applied. The stub
    /// holds `fetched` apart from `activeTests` to reproduce exactly that.
    @Test("Test An Override Is Not Rolled Back By A Later Fetch")
    func testOverrideIsNotRolledBackByALaterFetch() async throws {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: false, paywallTest: .custom))
        service.fetched = ActiveABTests(notificationsTest: false, paywallTest: .custom)
        let manager = ABTestManager(service: service)
        // Let the fetch `init` started land, so it cannot be the one counted below.
        _ = await TestManagers.eventually { service.fetchCount == 1 }

        try manager.override(updatedTests: ActiveABTests(notificationsTest: true, paywallTest: .storeKit))

        // Nothing may re-fetch on this path, and the override has to still be there afterwards.
        let refetched = await TestManagers.eventually(timeout: .seconds(1)) { service.fetchCount > 1 }
        #expect(refetched == false)
        #expect(manager.activeTests.paywallTest == .storeKit)
        #expect(manager.activeTests.notificationsTest)
    }

    /// Two overrides in a row, applied without waiting for the fetch `init` started. The last
    /// override has to win and stay won: the in-flight launch fetch returns the server's values,
    /// and landing after the overrides it would otherwise reset them.
    ///
    /// This is the same rollback as the test above, reached through `init` rather than through
    /// `override`, which is why the manager tracks that an override happened at all.
    @Test("Test Consecutive Overrides Keep The Last One")
    func testConsecutiveOverridesKeepTheLastOne() async throws {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: false, paywallTest: .custom))
        service.fetched = ActiveABTests(notificationsTest: false, paywallTest: .custom)
        let manager = ABTestManager(service: service)

        try manager.override(updatedTests: ActiveABTests(notificationsTest: true, paywallTest: .storeKit))
        try manager.override(updatedTests: ActiveABTests(notificationsTest: false, paywallTest: .revenueCat))

        #expect(manager.activeTests.paywallTest == .revenueCat)
        let movedAgain = await TestManagers.eventually(timeout: .seconds(1)) {
            manager.activeTests.paywallTest != .revenueCat
        }
        #expect(movedAgain == false)
    }

    @Test("Test A Rejected Override Throws And Changes Nothing")
    func testRejectedOverrideThrowsAndChangesNothing() {
        let service = StubService(activeTests: ActiveABTests(notificationsTest: false, paywallTest: .custom))
        service.saveError = ABTestStubError.failed
        let manager = ABTestManager(service: service)

        #expect(throws: ABTestStubError.self) {
            try manager.override(updatedTests: ActiveABTests(notificationsTest: true, paywallTest: .revenueCat))
        }

        #expect(service.savedTests.isEmpty)
        #expect(manager.activeTests.paywallTest == .custom)
        #expect(manager.activeTests.notificationsTest == false)
    }

    // MARK: - Events

    /// A fetch failure is logged as `.severe` because it means a slice of users is being counted
    /// in whichever variant they happened to have cached.
    @Test("Test The Fetch Events Keep Their Names And Severities")
    func testFetchEventsKeepTheirNamesAndSeverities() {
        let success = ABTestManager.Event.fetchRemoteConfigSuccess
        let failure = ABTestManager.Event.fetchRemoteConfigFail(error: ABTestStubError.failed)

        #expect(success.eventName == "ABMan_FetchRemote_Success")
        #expect(failure.eventName == "ABMan_FetchRemote_Fail")
        #expect(success.type == .analytic)
        #expect(failure.type == .severe)
        #expect(success.parameters == nil)
        #expect(failure.parameters?["error_code"] != nil)
    }

    // MARK: - ActiveABTests

    /// These strings are the column names in the analytics warehouse; renaming one silently splits
    /// a test's results across two columns.
    @Test("Test Event Parameters Use The Dated Test Keys")
    func testEventParametersUseTheDatedTestKeys() {
        let tests = ActiveABTests(notificationsTest: true, paywallTest: .revenueCat)

        let parameters = tests.eventParameters

        #expect(parameters["test_20251205_notifications_test"] as? Bool == true)
        #expect(parameters["test_20241205_PaywallTest"] as? String == "revenueCat")
        #expect(parameters.count == 2)
    }

    @Test("Test Omitting The Notifications Test Means Off Rather Than Unset")
    func testOmittingTheNotificationsTestMeansOff() {
        #expect(ActiveABTests(paywallTest: .custom).notificationsTest == false)
    }

    @Test("Test Updating One Test Leaves The Other Alone")
    func testUpdatingOneTestLeavesTheOtherAlone() {
        var tests = ActiveABTests(notificationsTest: true, paywallTest: .custom)

        tests.update(paywallTest: .storeKit)
        #expect(tests.paywallTest == .storeKit)
        #expect(tests.notificationsTest)

        tests.update(notificationsTest: false)
        #expect(tests.notificationsTest == false)
        #expect(tests.paywallTest == .storeKit)
    }

    /// The encoded keys are what Remote Config is keyed by, so the round trip has to survive the
    /// rename between the Swift property and the wire name.
    @Test("Test Active Tests Encode To The Remote Config Keys And Decode Back")
    func testActiveTestsEncodeToTheRemoteConfigKeys() throws {
        let tests = ActiveABTests(notificationsTest: true, paywallTest: .storeKit)

        let data = try JSONEncoder().encode(tests)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["_20251205_notifications_test"] as? Bool == true)
        #expect(json["_20241205_PaywallTest"] as? String == "storeKit")

        let decoded = try JSONDecoder().decode(ActiveABTests.self, from: data)
        #expect(decoded.notificationsTest)
        #expect(decoded.paywallTest == .storeKit)
    }

    /// `.default` is the arm a user falls into when Remote Config hands back a variant name this
    /// build has never heard of, so it has to stay one of the shipped cases.
    @Test("Test The Default Paywall Option Is A Real Case")
    func testTheDefaultPaywallOptionIsARealCase() {
        #expect(PaywallTestOption.default == .custom)
        #expect(PaywallTestOption.allCases.contains(.default))
        #expect(PaywallTestOption(rawValue: "not_a_variant") == nil)
    }

    // MARK: - LocalABTestService

    /// The dev build's service. It stores straight into `UserDefaults.standard` under the same
    /// keys Remote Config uses and takes no injection point, so this test restores whatever was
    /// there — and is the only test in the suite that touches those keys.
    @Test("Test The Local Service Persists An Override Across Instances")
    func testLocalServicePersistsAnOverrideAcrossInstances() async throws {
        let notificationsKey = ActiveABTests.CodingKeys.notificationsTest.rawValue
        let paywallKey = ActiveABTests.CodingKeys.paywallTest.rawValue
        let previous = [notificationsKey, paywallKey].map { ($0, UserDefaults.standard.object(forKey: $0)) }
        defer {
            for (key, value) in previous {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        let service = LocalABTestService()
        try service.saveUpdatedConfig(
            updatedTests: ActiveABTests(notificationsTest: true, paywallTest: .revenueCat)
        )

        #expect(service.activeTests.notificationsTest)
        #expect(service.activeTests.paywallTest == .revenueCat)

        // A second instance is what the next launch builds; the values live in UserDefaults, not
        // in the instance, so it has to see the same override.
        #expect(LocalABTestService().activeTests.paywallTest == .revenueCat)

        let fetched = try await service.fetchUpdatedConfig()
        #expect(fetched.paywallTest == .revenueCat)
        #expect(fetched.notificationsTest)
    }
}
