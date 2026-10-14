# analytics_repository

Event logging for Compound, ported from the Swift app's SwiftfulLogging. One call on
`AnalyticsRepository` goes to every service it was built with:

- `ConsoleService`: prints to the debug console. The staging flavor uses only this.
- `FirebaseAnalyticsService`: events, screen views, the user id and high-priority user properties.
  Parameters are cleaned as the Swift service does (names to 40 characters with spaces as
  underscores, text to 100, at most 25), and limited to `String` and `num`: a bool becomes 1 or 0,
  a date, enum or list becomes text, anything else is dropped. Names and emails are never sent.
- `CrashlyticsService`: a `LogType.severe` event becomes a non-fatal error; other events are
  breadcrumbs. Sets the user id.
- `MixpanelService`: the shared Mixpanel project on the EU servers, with `build_configuration` on
  every event. Create it with `MixpanelService.init`.

A service that fails is logged and never reaches the caller.

## Events

Declare a feature's events as an enum implementing `LoggableEvent`, as the Swift presenters'
`enum Event: LoggableEvent` do, and **reuse the Swift event names** (`TodayView_Appear`,
`TodayView_StartEmptyWorkout_Press`, `PaywallView_Purchase_AlreadyOwned`): `<Screen>_<Action>`, with
`_Fail` events usually `LogType.severe`. Matching names keep the dashboards continuous across the
two apps.

Run the tests with `very_good test --coverage --min-coverage 100`.
