# workout_session_repository

The signed-in user's workout sessions at `users/{uid}/workout_sessions`, **read-only** (M2).

- `FirestoreWorkoutSessionRepository` takes `FirebaseFirestore` through its constructor and reads
  the sessions whose `author_id` is the user, as the Swift app's listener does. Timestamps become
  UTC `DateTime`s here. A document that does not decode is skipped and reported to
  `onDecodeError` (or `dart:developer`'s log), as Swift's sync engine skips it, so one bad session
  never empties the list.
- `InMemoryWorkoutSessionRepository` serves a fixed list for the staging flavor and tests; seed it
  with `sampleWorkoutSessions(uid:, now:)`, a week of varied training.

The models are `compound_models`' (`WorkoutSessionModel` and its nested types), held to the
Firestore contract in [`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
There are no write methods.
