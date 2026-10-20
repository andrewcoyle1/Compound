# user_repository

The signed-in user's profile at `users/{uid}` and private settings at
`users/{uid}/private/settings`.

- `FirestoreUserRepository` takes `FirebaseFirestore` through its constructor. Timestamps become
  UTC `DateTime`s here. A document that does not decode reads as null and is reported to
  `onDecodeError` (or `dart:developer`'s log), never thrown into the stream.
- Writes: `createUser` (a new account's profile), `updateUserFields` (Firestore `update` of the
  fields Swift updates by name, typed by `UserField`; fails with `not-found` without a profile)
  and `mergePrivateSettings` (write `false` to turn something off, as coach consent is withdrawn).
- `InMemoryUserRepository` holds the documents in memory for the staging flavor and tests; seed it with
  `sampleUser(now:)` and `sampleUserSettings(now:)`, the Swift app's `UserModel.mockExisting`
  (uid `mock_user_123`, Alice Cooper).

The models are `compound_models`' `UserModel` and `PrivateUserSettings`, held to the Firestore
contract in [`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
Writes (M3) go through each model's `toFirestore`, with `DateTime`s stored as Timestamps. Whole
documents are merged (`SetOptions(merge: true)`), as Swift's `saveDocument` is, so a field this
app does not know survives; a merge also never clears a field the model leaves out. The in-memory
implementation merges the same way and re-emits to every watcher, so staging behaves like the
real app.
