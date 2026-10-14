# compound_models

Pure Dart models for the documents the Flutter app shares with the Swift app, held to the
Firestore contract in [`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).

Each model has `fromFirestore(Map<String, Object?>)` and `toFirestore()`, with timestamps as
`DateTime` (the repository maps them to and from `Timestamp`), and a `…Keys` class of field-name
constants that partial updates must use. `test/contract_test.dart` round-trips every fixture in
`contracts/firestore/` at the repository root.
