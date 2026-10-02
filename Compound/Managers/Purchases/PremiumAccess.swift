//
//  PremiumAccess.swift
//  Compound
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Foundation

/// The subscription gate every premium check in the app runs through.
///
/// `CoreInteractor.isPremium` used to return a hard-coded `true`, so nothing in a premium-only
/// app was actually gated. Restoring the entitlement check on its own would have made every
/// developer build demand an App Store subscription that a debug build cannot have — which is
/// presumably why it was stubbed, and why it would have been stubbed again. So the honest check
/// ships alongside a deliberate escape hatch rather than no check at all.
enum PremiumAccess {

    /// Whether the user should be treated as a subscriber.
    ///
    /// Deliberately a pure function of its inputs rather than a read of ``PremiumOverride``:
    /// the unit-test target is not built with `-DDEV`, so the override branch would be compiled
    /// out of any test that tried to exercise it through the flag.
    ///
    /// `entitlementsAreResolved` defaults to `true` so every existing call site and test that
    /// never heard of it keeps reading `entitlements` at face value. The one real caller that
    /// matters — ``CoreInteractor/isPremium`` — always passes it explicitly.
    ///
    /// This is a premium app: a user who is not a subscriber is always routed to the subscription
    /// page, no exceptions. But at cold launch there is a window where RevenueCat/StoreKit has not
    /// answered yet, and `entitlements` reads `[]` during it — identically to how it reads for a
    /// real non-subscriber. Gating on that would send a paying subscriber to the paywall because
    /// the network was slow, which is a worse bug than the one the gate exists to prevent. So the
    /// answer is optimistic — access granted — until the store has genuinely answered, and the
    /// gate is enforced from the moment it has.
    static func isPremium(
        entitlements: [PurchasedEntitlement],
        entitlementsAreResolved: Bool = true,
        developmentOverride: Bool
    ) -> Bool {
        if developmentOverride {
            return true
        }

        guard entitlementsAreResolved else {
            return true
        }

        return entitlements.hasActiveEntitlement
    }
}

/// Whether the store has answered at least once for the signed-in user.
///
/// `PurchaseManager.entitlements` (from the SwiftfulPurchasing package) starts as `[]` and only
/// updates once its listener or initial fetch completes — the same shape a real non-subscriber's
/// entitlements have. Nothing in the package distinguishes "no subscription" from "no answer
/// yet", so the app has to track the answer itself rather than infer it from a timer or from the
/// entitlements array alone.
///
/// This is app code rather than a change to `PurchaseManager`, which is a package type. It lives
/// in the dependency container next to `AppState` rather than on `CoreInteractor`, which is a
/// struct rebuilt per screen and so cannot hold state that needs to persist between reads.
@Observable
@MainActor
final class PremiumEntitlementResolution {

    private(set) var isResolved: Bool = false

    /// Called once `purchaseManager.logIn` has returned, which is the one moment the store has
    /// definitively answered for the signed-in user.
    func markResolved() {
        isResolved = true
    }

    /// Signing out hands the app to a user whose entitlements are unknown again, so the next
    /// session starts optimistic rather than inheriting this one's answer.
    func reset() {
        isResolved = false
    }
}

/// The development-only input to ``PremiumAccess/isPremium(entitlements:entitlementsAreResolved:developmentOverride:)``,
/// flipped from the "Simulate Premium" toggle in Developer Settings.
///
/// `DEV` arrives through `OTHER_SWIFT_FLAGS` on the app target's Debug configuration and `MOCK`
/// through the Mock configuration, so neither is defined for Release. In a shipping build the
/// storage key, the setter and the `UserDefaults` read are all absent from the binary and
/// `isEnabled` is a constant `false` — the override cannot be turned on by a defaults write, a
/// modified plist or a forgotten default, because there is nothing left to turn on.
@MainActor
enum PremiumOverride {

    #if DEV || MOCK
    static let storageKey = "dev_simulate_premium"

    /// Mock is the previews and UI-test configuration, where the whole app has to be reachable
    /// with no store behind it, so it starts on. A dev build talks to the real dev backend and
    /// starts honest, so the gate is what a developer sees unless they ask otherwise.
    #if MOCK
    private static let startingValue = true
    #else
    private static let startingValue = false
    #endif

    @UserDefault(key: storageKey, startingValue: startingValue)
    static var isEnabled: Bool
    #else
    static var isEnabled: Bool { false }
    #endif
}
