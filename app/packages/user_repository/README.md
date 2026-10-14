# user_repository

The signed-in user's profile at `users/{uid}` and private settings at
`users/{uid}/private/settings`, **read-only** (M1).

- `FirestoreUserRepository` takes `FirebaseFirestore` through its constructor. Timestamps become
  UTC `DateTime`s here. A document that does not decode reads as null and is reported to
  `onDecodeError` (or `dart:developer`'s log), never thrown into the stream.
- `InMemoryUserRepository` serves fixed documents for the staging flavor and tests; seed it with
  `sampleUser(now:)` and `sampleUserSettings(now:)`, the Swift app's `UserModel.mockExisting`
  (uid `mock_user_123`, Alice Cooper).

The models are `compound_models`' `UserModel` and `PrivateUserSettings`, held to the Firestore
contract in [`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
There are no write methods.
