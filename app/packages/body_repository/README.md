# body_repository

The signed-in user's body measurements, steps, analytics settings and current weight goal.
It saves measurements and goals.

- `FirestoreBodyRepository` takes `FirebaseFirestore` through its constructor and watches:
  - `users/{uid}/body_measurements` where `author_id` is the user, as the Swift app's listener does;
  - `users/{uid}/steps`, filtered to the user's own on the client, as Swift's screens do;
  - `users/{uid}/analytics_settings/analytics_settings` (Swift's defaults when absent);
  - `users/{uid}/goals/{currentGoalId ?? uid}`, as `GoalManager.signIn` picks it (null when absent).

  Entries with a `deleted_at` are left out, as every Swift screen leaves them out, and lists come
  oldest first. Timestamps become UTC `DateTime`s. A document that does not decode is skipped and
  reported to `onDecodeError` (or `dart:developer`'s log), as Swift's sync engine skips it.
- Writes: `saveMeasurement`, `saveGoal` (a new goal; the rules freeze where a goal started) and
  `abandonGoal` (`status` only). Clearing a measurement's value is not supported yet: a merge
  cannot clear, which is Swift's `withCleared` bug.
- `InMemoryBodyRepository` holds the data for the staging flavor and tests; seed it with
  `sampleBodyMeasurements`, `sampleSteps` and `sampleWeightGoal` (stored under the uid, so it is
  current for a user with no `currentGoalId`). With no settings given it serves the defaults.

The models are `compound_models'`, held to the Firestore contract in
[`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
Writes (M3) go through each model's `toFirestore`, with `DateTime`s stored as Timestamps. Whole
documents are merged (`SetOptions(merge: true)`), as Swift's `saveDocument` is, so a field this
app does not know survives; a merge also never clears a field the model leaves out. The in-memory
implementation merges the same way and re-emits to every watcher, so staging behaves like the
real app.
