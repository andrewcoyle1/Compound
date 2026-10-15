# notifications_repository

Notifications for Compound, ported from the Swift app's `PushManager`, `DeepLink`,
`RestOverNotifying`, `IdleWorkoutReminder` and `ReminderOfferFlow`. No UI.

- `DeepLink`: `compound://tab/<name>` (and `?name=`), `compound://join/<code>`,
  `compound://workout`, and the same destinations from a notification's data (`deep_link`,
  `type`, `session_id` + `session_author_id`, `tab`, as `functions/lib.js` sends them).
  `toLocation()` gives the router path; destinations not built yet land on the tab Swift opens
  them from.
- `LocalReminders`: the local notifications as pure plans (come-back 1/3/5 days, meals at
  08:00/12:30/18:30, rest over, idle workout), with `RestOverAlert`, `IdleWorkout`,
  `ForegroundPresentation` and `ReminderOffer`.
- `NotificationsRepository`: permission, push-token sync into `users/{uid}/private/settings`
  (`fcm_token` and `timezone`, never the public profile), foreground messages, a `DeepLinkInbox`
  for taps, and scheduling. `FirebaseNotificationsRepository` uses `firebase_messaging` (BSD-3),
  `flutter_local_notifications` (BSD-3), `timezone` (BSD-2) and `flutter_timezone` (Apache-2.0);
  `FakeNotificationsRepository` is for the staging flavor and tests.

Words come from the app through `NotificationCopy`. Run the tests with the very_good_cli `test`
tool at `min_coverage: 100`.
