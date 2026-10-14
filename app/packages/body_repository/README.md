# body_repository

The signed-in user's body measurements, steps, analytics settings and current weight goal,
**read-only** (M2).

- `FirestoreBodyRepository` takes `FirebaseFirestore` through its constructor and watches:
  - `users/{uid}/body_measurements` where `author_id` is the user, as the Swift app's listener does;
  - `users/{uid}/steps`, filtered to the user's own on the client, as Swift's screens do;
  - `users/{uid}/analytics_settings/analytics_settings` (Swift's defaults when absent);
  - `users/{uid}/goals/{currentGoalId ?? uid}`, as `GoalManager.signIn` picks it (null when absent).

  Entries with a `deleted_at` are left out, as every Swift screen leaves them out, and lists come
  oldest first. Timestamps become UTC `DateTime`s. A document that does not decode is skipped and
  reported to `onDecodeError` (or `dart:developer`'s log), as Swift's sync engine skips it.
- `InMemoryBodyRepository` serves fixed data for the staging flavor and tests; seed it with
  `sampleBodyMeasurements`, `sampleSteps` and `sampleWeightGoal` (stored under the uid, so it is
  current for a user with no `currentGoalId`). With no settings given it serves the defaults.

The models are `compound_models'`, held to the Firestore contract in
[`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
There are no write methods.
