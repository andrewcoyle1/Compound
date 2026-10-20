# purchases_repository

Subscriptions for Compound, ported from the Swift app's `PurchaseManager` (SwiftfulPurchasing with
RevenueCat) and `PremiumAccess`.

- `PurchasesRepository`: products, purchase, restore, refresh, `logIn(uid)` / `logOut()`, and
  `state` / `states` (the entitlements and whether the store has answered for the signed-in user).
- `RevenueCatPurchasesRepository.init(apiKey:, appUserId:)`: RevenueCat through
  `purchases_flutter` (MIT). The app user id is the **Firebase uid**, as in the Swift app and the
  coach's server-side premium check, so a subscription bought on either app unlocks both. An empty
  `apiKey` means the build has none: the state is resolved and not premium, and loading products,
  buying or restoring throws `PurchasesNotConfigured`.
- `FakePurchasesRepository`: no store, for the staging flavor and tests. Sells the Swift
  development StoreKit products (Pro Annual £29.99, Pro Monthly £4.99); premium by default; queue
  `failures` (and `failedLoads`) to show every paywall state.
- `isPremium(...)` / `PurchasesState.isPremiumWith(...)`: the premium gate. Any active entitlement
  counts (no entitlement id is checked, as in Swift). Until the store has answered for the
  signed-in user the answer is optimistic, so a slow network never sends a subscriber to the
  paywall. A development override grants access and never removes it.
- `SubscriptionPlan`: the yearly and monthly product ids (`com.andrewcoyle.compound[.dev].yearly`).

Purchase outcomes a paywall treats differently are their own `PurchasesFailure` subclasses:
`PurchaseCancelled` (say nothing), `PurchasePending` (show inline), `ProductAlreadyOwned`
(restore instead) and `ProductNotFound`.

Run the tests with `very_good test --coverage --min-coverage 100`.
