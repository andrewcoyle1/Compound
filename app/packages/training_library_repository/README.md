# training_library_repository

Reads the signed-in user's training library from Firestore, or from memory in the staging flavor:
their exercises (top-level `exercise_templates`, by `author_id`), workout templates, gym profiles,
exercise settings and workout settings. Read-only until these contracts have been exercised by
writes ([`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md)).

`PrebuiltCatalogue` holds the system exercises and workouts the Swift app bundles and seeds locally
at sign-in. Their JSON is embedded byte for byte; when the Swift app's files change, the test says
so, and the copies are regenerated from this folder with:

```bash
dart ../compound_models/tool/embed_json.dart ../../../Compound/SupportingFiles/Resources/PrebuiltExercises.json lib/src/prebuilt_exercises_json.dart prebuiltExercisesJson
dart ../compound_models/tool/embed_json.dart ../../../Compound/SupportingFiles/Resources/PrebuiltWorkouts.json lib/src/prebuilt_workouts_json.dart prebuiltWorkoutsJson
```
