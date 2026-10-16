# ab_test_repository

The A/B tests the Swift app runs (`ABTestManager`), with Swift's keys and defaults:
`notificationsTest` (`_20251205_notifications_test`, default `false`) and `paywallTest`
(`_20241205_PaywallTest`, default `custom`).

- `RemoteConfigAbTestRepository`: Firebase Remote Config, as Swift's `FirebaseABTestService`
  (production). The defaults are set in code, so with no console parameters every user gets them.
- `LocalAbTestRepository`: a random draw kept in `device_store` under the same keys, as Swift's
  `LocalABTestService` (development). Developer Settings can override it.
- `InMemoryAbTestRepository`: the defaults, or what a test passes (staging and tests).
