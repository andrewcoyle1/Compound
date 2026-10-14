# Firestore contract: Swift and Flutter share documents

The safeguard against the Flutter app corrupting data the Swift app reads.
Both apps write the same documents. Swift **silently drops** any document it can't decode
(`Query+CollectionChanges.swift:58,67`, `Firestore+EXT.swift:20`), so one bad Flutter write makes
data disappear from the iOS app without an error. The contract makes that a failing test.

1. **Fixtures**: `contracts/firestore/<model>/<case>.json`, with Timestamps tagged
   `{"$timestamp": "<ISO-8601>"}`.
   - Each model has a `full` case (every optional present) and a `minimal` case (required fields
     only).
   - Each model also has a `legacy-*` case for every backwards-compatible shape Swift accepts,
     for example a `WeightGoal` with no `goal_id`, a share with `kind: "program"`, and
     `SetTargetSetType` stored as an object.
2. **Swift side** (`CompoundUnitTests/Contracts/FirestoreContractTests.swift`): uses the real
   `Firestore.Decoder`/`Encoder`. Every existing round-trip test uses `JSONEncoder` with
   milliseconds, so none of them see real Timestamps.
   - Every fixture must decode.
   - Every canonical fixture must re-encode to exactly itself.
   - Fixtures are loaded from disk the way `CoachParityTests.swift:22-32` does it.
   - `RECORD_CONTRACTS=1` regenerates fixtures from fixed sample instances, because `.mock` uses
     `Date()`.
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
   - Dart repositories take field names only from constants on the model.
   - A test asserts every such constant is a key in the model's `full` fixture.
5. **Rules**: `functions/rules.test.js` creates every `full` fixture under its path and expects the
   emulator to accept it. That's the class of bug behind the mesocycle-share problem.
6. **Policy:**
   - No Flutter repository may write to a collection until that model's contract passes on both
     sides.
   - Dart writes use `SetOptions(merge: true)`, as Swift does, so a top-level field Dart doesn't
     know about survives.
   - At M6 the source of truth flips to Dart.
7. **CI**:
   - A new `Flutter` job in `.github/workflows/ci.yml` runs `very_good test --coverage` for `app/`
     and its packages.
   - The Swift contract tests run in the existing unit job.
   - Once stable, both become required checks on `main`.

