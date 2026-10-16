# device_store

Small values kept on this device, as the Swift app keeps them in `UserDefaults`: dismissed cards,
the last time something was asked, per-exercise units. `SharedPreferencesDeviceStore` keeps them
in the platform's store; `InMemoryDeviceStore` is for the staging flavor and tests.
