# training_library_repository

Reads the signed-in user's training library from Firestore, or from memory in the staging flavor:
their exercises (top-level `exercise_templates`, by `author_id`), workout templates, gym profiles,
exercise settings and workout settings, held to the Firestore contract
([`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md)).
It writes gym profiles (`saveGymProfile`) and exercise settings (`saveExerciseSettings`, a note
or a rest override), each merged as Swift's managers save them.

`PrebuiltCatalogue` holds the system exercises and workouts seeded locally at sign-in. Their JSON
lives in `contracts/catalogue/` (shared with `functions/data/PrebuiltExercises.json`, which a
functions test holds to a byte-for-byte copy) and is embedded here byte for byte; when a file
there changes, the test says so, and the copies are regenerated from this folder with:

```bash
dart ../compound_models/tool/embed_json.dart ../../../contracts/catalogue/PrebuiltExercises.json lib/src/prebuilt_exercises_json.dart prebuiltExercisesJson
dart ../compound_models/tool/embed_json.dart ../../../contracts/catalogue/PrebuiltWorkouts.json lib/src/prebuilt_workouts_json.dart prebuiltWorkoutsJson
```
