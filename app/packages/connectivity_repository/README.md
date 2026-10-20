# connectivity_repository

Whether the device has a network, for the actions that need the server to answer before they can
finish (Swift's `NetworkMonitor.swift`). `ConnectivityRepository.ensureOnline` is Swift's
`ensureOnline(or:)`: false without a network, after telling `blocked`, which the app turns into
the "You're offline" alert and the `Offline_ActionBlocked` event. It keeps the last status
connectivity_plus reported, so the check is synchronous, as Swift's is, and an unknown status
counts as online. `FakeConnectivityRepository` is online until `offline` is set, for the
staging flavor and tests.

Built on `connectivity_plus` (BSD-3). Coverage is held at 100%.
