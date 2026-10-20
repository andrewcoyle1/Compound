# contracts

Data shared between the Flutter app (`app/`) and the Cloud Functions (`functions/`), and the
fixtures that pin it down.

| Folder | What | Read by |
|---|---|---|
| `firestore/` | The Firestore contract: one folder per model, `full`, `minimal` and `legacy-*` cases, plus `enums.json` | `compound_models/test/contract_test.dart` and the repositories' Firestore tests |
| `fixtures/` | Parity fixtures (`coach`, `nutrition`, `progression`, `tracker`, `program`) and the program-import samples in `programs/` | `compound_maths`, `training_rules`, `training_session`, `program_repository`, the app's program tests, `functions/coach-maths.test.js` |
| `catalogue/` | The bundled exercises, workouts and mesocycles (`Prebuilt*.json`) | `training_library_repository` embeds them byte for byte; `functions/data/PrebuiltExercises.json` must stay an exact copy of `PrebuiltExercises.json` (`functions/coach.test.js` checks) |

## The Swift side is gone, its readers are not

These files were written by the SwiftUI app and checked by both its tests and the Dart ones. The
Swift app was removed from this repository on 20 Oct 2026; it is preserved at the
`swift-app-store` tag (exactly what is on the App Store), the `swift-final` tag and the
`archive/swift` branch.

The App Store Swift clients still read and write the same Firestore documents, and Swift
**silently drops** any document it cannot decode. So the shapes in `firestore/` stay frozen as
Swift-compatible:

- Never rename or retype an existing field, and never make an optional field required.
- A new field must be optional, so an old client that does not know it still decodes the document.
- Keep the `legacy-*` cases: they are shapes the Swift clients accept and may still write.
- A change to a fixture is a change to the contract. Check it against the Swift models in the
  archive (`CompoundUnitTests/Contracts/FirestoreContractTests.swift` at `swift-final`) until no
  supported Swift client is left.

The parity fixtures were recorded from the Swift app and are now frozen: the Dart ports are the
source of truth, and the fixtures stay as their regression checks. `coach-parity.json`'s
expected values are rewritten from the JavaScript with `node scripts/coach-parity-expected.mjs`
after changing the maths in both `functions/coach-maths.js` and `compound_maths`.

See `docs/specs/flutter/firestore-contract.md` for the contract's rules.
