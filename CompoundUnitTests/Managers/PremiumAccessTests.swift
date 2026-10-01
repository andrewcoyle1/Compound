//
//  PremiumAccessTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The subscription gate. `isPremium` shipped hard-coded to `true`, so every premium check in the
/// app was open; these tests are the regression signal that it now answers from the entitlement.
///
/// The override half is mostly tested through the pure `developmentOverride` parameter rather than
/// the `DEV` flag, so the decision is pinned independently of whichever configuration the tests
/// happen to be built in.
@MainActor
struct PremiumAccessTests {

    private func entitlement(isActive: Bool) -> PurchasedEntitlement {
        PurchasedEntitlement(
            id: UUID().uuidString,
            productId: "com.dialedin.premium.monthly",
            expirationDate: Date().addingTimeInterval(60 * 60 * 24 * 7),
            isActive: isActive,
            originalPurchaseDate: .now,
            latestPurchaseDate: .now,
            ownershipType: .purchased,
            isSandbox: true,
            isVerified: true
        )
    }

    @Test("An entitled user reads as premium")
    func entitledUserIsPremium() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: true)],
            developmentOverride: false
        )

        #expect(result == true)
    }

    @Test("A user with no entitlements is not premium")
    func userWithNoEntitlementsIsNotPremium() {
        let result = PremiumAccess.isPremium(entitlements: [], developmentOverride: false)

        #expect(result == false)
    }

    /// A lapsed subscriber keeps the entitlement record; only `isActive` drops. This is the case
    /// the hard-coded `true` was hiding, and the one the app's revenue depends on.
    @Test("A lapsed subscriber is not premium")
    func lapsedSubscriberIsNotPremium() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: false)],
            developmentOverride: false
        )

        #expect(result == false)
    }

    @Test("One active entitlement among expired ones is enough")
    func oneActiveEntitlementIsEnough() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: false), entitlement(isActive: true)],
            developmentOverride: false
        )

        #expect(result == true)
    }

    @Test("The development override grants premium without an entitlement")
    func developmentOverrideGrantsPremium() {
        let result = PremiumAccess.isPremium(entitlements: [], developmentOverride: true)

        #expect(result == true)
    }

    /// The override must never be the thing that denies access — a developer who has flipped it on
    /// and also has a real subscription still sees the app.
    @Test("The development override never removes real access")
    func developmentOverrideDoesNotRemoveAccess() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: true)],
            developmentOverride: true
        )

        #expect(result == true)
    }

    /// The override end to end, as it exists in the configuration these tests are built against.
    ///
    /// `DEV` and `MOCK` are app-target flags, so `PremiumOverride` is compiled according to the
    /// running scheme's configuration, not the test target's — Development and Mock each define
    /// one, which is why the stored value is readable below. Release defines neither: there
    /// `isEnabled` is a constant `false` with no key and no `UserDefaults` read behind it, so no
    /// defaults write can reach it. That half cannot be asserted from here, because proving it
    /// takes the Release compiler rather than a test.
    @Test("The development override is read from its stored value")
    func developmentOverrideIsReadFromStorage() {
        let key = "dev_simulate_premium"
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set(true, forKey: key)
        #expect(PremiumAccess.isPremium(entitlements: [], developmentOverride: PremiumOverride.isEnabled) == true)

        UserDefaults.standard.set(false, forKey: key)
        #expect(PremiumAccess.isPremium(entitlements: [], developmentOverride: PremiumOverride.isEnabled) == false)
    }

    // MARK: - Optimistic access until resolution

    /// The window between cold launch and RevenueCat/StoreKit answering: `entitlements` reads `[]`
    /// during it, identically to a real non-subscriber. This is a premium app — non-subscribers
    /// are always routed to the paywall — but routing a paying subscriber there because the
    /// network was slow is unacceptable, so the unresolved answer is always "let them in".
    @Test("An unresolved answer grants access even with no entitlements")
    func unresolvedAnswerGrantsAccess() {
        let result = PremiumAccess.isPremium(
            entitlements: [],
            entitlementsAreResolved: false,
            developmentOverride: false
        )

        #expect(result == true)
    }

    @Test("A resolved entitled user is granted access")
    func resolvedEntitledUserIsGrantedAccess() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: true)],
            entitlementsAreResolved: true,
            developmentOverride: false
        )

        #expect(result == true)
    }

    /// The gate the whole feature exists for: once the store has genuinely answered "no
    /// subscription", the user is routed to the paywall — optimism is a grace window, not a
    /// permanent bypass.
    @Test("A resolved non-entitled user is sent to the paywall")
    func resolvedNonEntitledUserIsSentToPaywall() {
        let result = PremiumAccess.isPremium(
            entitlements: [],
            entitlementsAreResolved: true,
            developmentOverride: false
        )

        #expect(result == false)
    }

    @Test("A resolved lapsed subscriber is sent to the paywall")
    func resolvedLapsedSubscriberIsSentToPaywall() {
        let result = PremiumAccess.isPremium(
            entitlements: [entitlement(isActive: false)],
            entitlementsAreResolved: true,
            developmentOverride: false
        )

        #expect(result == false)
    }

    /// Existing call sites and tests never pass `entitlementsAreResolved`, and the default must
    /// keep reading `entitlements` at face value rather than silently going optimistic.
    @Test("Omitting entitlementsAreResolved reads entitlements at face value")
    func omittingEntitlementsAreResolvedReadsEntitlementsAtFaceValue() {
        #expect(PremiumAccess.isPremium(entitlements: [], developmentOverride: false) == false)
        #expect(PremiumAccess.isPremium(entitlements: [entitlement(isActive: true)], developmentOverride: false) == true)
    }

    /// The override wins regardless of resolution state — a developer build must never be blocked
    /// by the store not having answered, any more than by a real lack of entitlement.
    @Test("The development override grants access whether or not entitlements are resolved")
    func developmentOverrideGrantsAccessRegardlessOfResolution() {
        #expect(PremiumAccess.isPremium(entitlements: [], entitlementsAreResolved: false, developmentOverride: true) == true)
        #expect(PremiumAccess.isPremium(entitlements: [], entitlementsAreResolved: true, developmentOverride: true) == true)
    }
}

/// The runtime signal `PremiumAccess.isPremium` needs and `PurchaseManager` does not expose:
/// whether the store has answered at all for the signed-in user. Genuinely distinguishable from
/// "false" — a separate boolean the app sets once it has heard back — rather than inferred from
/// elapsed time.
@MainActor
struct PremiumEntitlementResolutionTests {

    @Test("A fresh resolution starts unresolved")
    func freshResolutionStartsUnresolved() {
        let resolution = PremiumEntitlementResolution()

        #expect(resolution.isResolved == false)
    }

    @Test("Marking resolved flips it to resolved")
    func markingResolvedFlipsItToResolved() {
        let resolution = PremiumEntitlementResolution()

        resolution.markResolved()

        #expect(resolution.isResolved == true)
    }

    /// Signing out hands the app to a user whose entitlements are unknown again, so the next
    /// session starts optimistic rather than inheriting this one's answer.
    @Test("Resetting returns it to unresolved")
    func resettingReturnsItToUnresolved() {
        let resolution = PremiumEntitlementResolution()

        resolution.markResolved()
        resolution.reset()

        #expect(resolution.isResolved == false)
    }
}
