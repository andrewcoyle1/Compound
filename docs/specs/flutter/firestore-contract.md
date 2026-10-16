# Firestore contract: Swift and Flutter share documents

The safeguard against the Flutter app corrupting data the Swift app reads.
Both apps write the same documents. Swift **silently drops** any document it can't decode
(`Query+CollectionChanges.swift:58,67`, `Firestore+EXT.swift:20`), so one bad Flutter write makes
data disappear from the iOS app without an error. The contract makes that a failing test.

1. **Fixtures**: `contracts/firestore/<model>/<case>.json`, with Timestamps tagged
   `{"$timestamp": "2026-01-02T03:04:05.123Z"}`: UTC, exactly three fractional digits. Swift holds
   a `Date` as a Double, so the contract is to the millisecond; the converters round to it.
   - Numbers keep their type: `172.5` is a double and `4` an int, and the tests on both sides
     compare types, so a Dart write cannot turn an Int field into a double. Samples use doubles
     that aren't whole numbers, because JSON writes `172.0` as `172`.
   - A NaN or infinity, which JSON cannot hold, is tagged `{"$double": "NaN"}` (or `"Infinity"`,
     `"-Infinity"`). Only legacy inputs use it: `NutrientMap` drops such values on read.
   - `contracts/firestore/enums.json` lists every raw value of the enums the models store.
   - Each model has a `full` case (every optional present) and a `minimal` case (required fields
     only).
   - Each model also has a `legacy-*` case for every backwards-compatible shape Swift accepts,
     for example a `WeightGoal` with no `goal_id`, a share with `kind: "program"`, and
     `SetTargetSetType` stored as an object. Legacy cases are hand-written, and each is paired
     with `legacy-*.expected.json`: what Swift writes back after decoding it. Both sides check
     that pair.
2. **Swift side** (`CompoundUnitTests/Contracts/FirestoreContractTests.swift`): uses the real
   `Firestore.Decoder`/`Encoder`. Every existing round-trip test uses `JSONEncoder` with
   milliseconds, so none of them see real Timestamps.
   - Every fixture must decode.
   - Every canonical fixture must re-encode to exactly itself.
   - Fixtures are loaded from disk the way `CoachParityTests.swift:22-32` does it.
   - `RECORD_CONTRACTS=1` regenerates the canonical fixtures (and `enums.json`) from fixed sample
     instances, because `.mock` uses `Date()`. Through xcodebuild, pass it as
     `TEST_RUNNER_RECORD_CONTRACTS=1`.
   - The `full` sample must set every optional property (checked by reflection), and the fixture
     must equal the encoded sample, so a new Swift field fails here until it is recorded.
   - While Swift is still live, **Swift is the source of truth**: a Swift model change re-records
     the fixtures, and the Dart test then fails until Dart catches up.
3. **Dart side** (`compound_models/test/contract_test.dart`): every fixture goes through
   `fromFirestore` and then `toFirestore`, and must come back equal to the fixture.
   - Every key the Swift fixture has must survive, so a field Dart doesn't know about fails the
     test.
   - Dart also has to match the shapes the review flagged:
     - nil is *omitted*, not written as null.
     - `isWarmup` is camelCase.
     - `MealItemModel` and `DietPlan` keys are camelCase.
     - `OverarchingObjective` is stored as a **keyed map** like `{"loseWeight": {}}`, not a string.
       Swift decodes it strictly, so a Dart string would break goals on iOS.
4. **Partial updates**: Swift updates single fields by name (`UserManager.swift:119-365`, session
   `strava_activity_id` and `week_streak_count`, goal `status`, and others).
   - Dart repositories take field names only from constants on the model (`UserModelKeys`,
     `PrivateUserSettingsKeys`, …).
   - The Dart test asserts those constants are exactly the keys of the model's `full` fixture.
     The Swift test lists the fields the app writes or queries by name and asserts each is a key
     there too.
5. **Rules**: `functions/rules.test.js` creates every `full` fixture under its path and expects the
   emulator to accept it. That's the class of bug behind the mesocycle-share problem.
6. **Policy:**
   - No Flutter repository may write to a collection until that model's contract passes on both
     sides.
   - Dart writes use `SetOptions(merge: true)`, as Swift does, so a top-level field Dart doesn't
     know about survives.
   - At M6 the source of truth flips to Dart.
   - **Writes complete once Firestore has them locally, not when the server acknowledges.**
     cloud_firestore's `set`, `update` and `commit` futures complete only on the server's
     acknowledgement, so offline a repository that awaited them would never return and the
     screen's spinner would hang. Firestore applies each write to its local cache, and queues it
     durably, as soon as it is started, as Swift's sync engines do with their pending writes.
     Every repository write goes through `writeLocally` (`compound_models`,
     `firestore_writes.dart`):
     - it completes when the write does, or after one turn of the event loop, whichever is first;
     - an error raised while starting the write (an encoder rejecting a value) still fails the
       returned future, so the caller can say the save failed;
     - anything later can only come from the server (`permission-denied`, `not-found` for an
       `update()` of a missing document, as Swift reports it). It goes to the repository's
       `onWriteError`, a `WriteErrorReporter`. The default logs at the severe level; the app
       passes one that also tracks a severe `Firestore_Write_Fail` event, which Crashlytics
       records as a non-fatal error. A refused write is reverted in the local cache, and the
       listeners show that.
     - Reads are not changed. A write that needs a read first (`endLoggingBreak`) still waits for
       that read, which Firestore answers from its cache once it knows it is offline. A
       transaction or anything reading a server value must keep awaiting the server; none exists
       yet, and one should say why in its doc comment.
     - In-memory repositories stay synchronous. Each repository's `offline_writes_test.dart` runs
       its writes against an `OfflineFirestore` that never answers, then refuses them.
7. **CI**:
   - A new `Flutter` job in `.github/workflows/ci.yml` runs `very_good test --coverage` for `app/`
     and its packages.
   - The Swift contract tests run in the existing unit job.
   - Once stable, both become required checks on `main`.

## How to add a model
1. **Swift** (`CompoundUnitTests/Contracts/FirestoreContractTests.swift`):
   - Add a `full` sample (every optional set, fixed dates) and a `minimal` one to `Samples`.
   - Add a `contract(...)` line to `contracts()`, with the fields the app updates or queries by
     name (grep the manager for `updateDocument` and `CodingKeys.`).
   - Add any stored enum to `enumRawValuesMatch`.
   - Run the suite once with `TEST_RUNNER_RECORD_CONTRACTS=1`. It fails that once, because the
     folder didn't exist when the decode test listed it. Then run it again without the variable.
   - A model the app writes and parses as a plain dictionary (notifications, comments, reports,
     username reservations) cannot go through the coders. Use `dictionaryContract` with a test-side
     mirror of the service's write and parse, copied line for line, and add the service file to
     `serviceKeysMatchFixtures`, which fails when the service names a key the full fixture lacks
     or the reverse (`FirestoreContractTests+Social.swift`).
2. **Legacy shapes:** read the model's `init(from:)` and its git history (`git log -p` on the
   file, looking for removed or renamed `CodingKeys`). Hand-write a `legacy-<name>.json` for each
   shape it still accepts, with its `.expected.json`.
3. **Dart** (`app/packages/compound_models`):
   - Add the model with `fromFirestore`/`toFirestore` and a `…Keys` class.
   - Register it in `_models` in `test/contract_test.dart`. Until then, that test fails on the
     new folder.
4. **Rules:** add its `full` fixture to the contract test in `functions/rules.test.js`, at its
   real path.
   If a Cloud Function reads or writes the document, list the fields it reads, and check the
   shape it writes, in the no-emulator tests at the end of the social contract section there.
5. **App data a decoder reads:** `GymProfileModel`'s decoder appends every catalogue item a stored
   list lacks, so the catalogue is part of the contract. The Swift test records it to
   `contracts/firestore/gym_equipment_catalogue.json` (each nested entry's random id made
   `<item id>_<n>`), and `compound_models` embeds that file with `tool/embed_json.dart`; a test on
   each side fails when it drifts. Canonical gym fixtures therefore hold the whole catalogue, and
   legacy cases that exercise the merge use lists whose catalogue has no random ids.
