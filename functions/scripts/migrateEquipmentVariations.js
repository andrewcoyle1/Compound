/**
 * migrateEquipmentVariations.js
 *
 * Backfills `equipment_variations` on embedded ExerciseModel snapshots that
 * are missing the field, inside:
 *   - users/{uid}/workout_templates/{docId}  →  exercises[*].exercise
 *   - users/{uid}/training_programs/{docId}  →  workout_templates[*].exercises[*].exercise
 *
 * The canonical variation data is read from PrebuiltExercises.json and looked
 * up by exercise `id`. Exercises not found in the prebuilt list get `[]`.
 *
 * Usage:
 *   node scripts/migrateEquipmentVariations.js --project <projectId> [--dry-run]
 *
 * Auth:
 *   Uses Application Default Credentials. Run `firebase login` first, or set
 *   GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON path.
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

// ── CLI args ──────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const projectFlagIdx = args.indexOf("--project");
const projectId =
  projectFlagIdx !== -1
    ? args[projectFlagIdx + 1]
    : process.env.GCLOUD_PROJECT ?? process.env.FIREBASE_PROJECT;

if (!projectId) {
  console.error(
    "ERROR: Supply a project ID via --project <id> or the GCLOUD_PROJECT env var."
  );
  process.exit(1);
}

console.log(`Project : ${projectId}`);
console.log(`Dry run : ${dryRun}`);
console.log("─".repeat(50));

// ── Load prebuilt exercise data ───────────────────────────────────────────────
const __dir = dirname(fileURLToPath(import.meta.url));
const prebuiltPath = resolve(
  __dir,
  "../data/PrebuiltExercises.json"
);

let variationsByExerciseId;
try {
  const raw = JSON.parse(readFileSync(prebuiltPath, "utf8"));
  variationsByExerciseId = new Map(
    raw.exercises.map((ex) => [ex.id, ex.equipment_variations ?? []])
  );
  console.log(`Loaded ${variationsByExerciseId.size} exercises from PrebuiltExercises.json\n`);
} catch (err) {
  console.error("ERROR: Could not load PrebuiltExercises.json:", err.message);
  process.exit(1);
}

// ── Firebase init ─────────────────────────────────────────────────────────────
initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();

// ── Helpers ───────────────────────────────────────────────────────────────────

function needsMigration(exercise) {
  return exercise != null && !Object.prototype.hasOwnProperty.call(exercise, "equipment_variations");
}

/**
 * Patches an exercise object in-place with the canonical equipment_variations.
 * Falls back to [] if the exercise ID isn't in the prebuilt list.
 * Returns true when a change was made.
 */
function patchExercise(exercise) {
  if (!needsMigration(exercise)) return false;

  const variations = variationsByExerciseId.get(exercise.id) ?? [];
  exercise.equipment_variations = variations;

  if (variations.length === 0) {
    console.warn(`  ⚠️  No prebuilt variations found for exercise id="${exercise.id}" (name="${exercise.name}") — set to []`);
  }
  return true;
}

// ── Migration ─────────────────────────────────────────────────────────────────

async function migrateWorkoutTemplates(uid) {
  const col = db.collection(`users/${uid}/workout_templates`);
  const snap = await col.get();
  let updated = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const exercises = data.exercises ?? [];
    let dirty = false;

    for (const entry of exercises) {
      if (entry?.exercise && patchExercise(entry.exercise)) dirty = true;
    }

    if (dirty) {
      updated++;
      console.log(`  [workout_template] ${doc.id}`);
      if (!dryRun) await doc.ref.update({ exercises });
    }
  }
  return updated;
}

async function migrateTrainingPrograms(uid) {
  const col = db.collection(`users/${uid}/training_programs`);
  const snap = await col.get();
  let updated = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const workoutTemplates = data.workout_templates ?? [];
    let dirty = false;

    for (const wt of workoutTemplates) {
      for (const entry of wt?.exercises ?? []) {
        if (entry?.exercise && patchExercise(entry.exercise)) dirty = true;
      }
    }

    if (dirty) {
      updated++;
      console.log(`  [training_program] ${doc.id}`);
      if (!dryRun) await doc.ref.update({ workout_templates: workoutTemplates });
    }
  }
  return updated;
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const usersSnap = await db.collection("users").get();
  console.log(`Found ${usersSnap.size} user(s).\n`);

  let totalDocs = 0;

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    console.log(`User: ${uid}`);

    const wtUpdated = await migrateWorkoutTemplates(uid);
    const tpUpdated = await migrateTrainingPrograms(uid);
    const userTotal = wtUpdated + tpUpdated;

    if (userTotal > 0) {
      totalDocs += userTotal;
      console.log(`  → ${userTotal} doc(s) ${dryRun ? "would be" : ""} updated\n`);
    } else {
      console.log("  → no changes needed\n");
    }
  }

  console.log("─".repeat(50));
  if (dryRun) {
    console.log(`DRY RUN complete. ${totalDocs} doc(s) would be updated.`);
  } else {
    console.log(`Migration complete. ${totalDocs} doc(s) updated.`);
  }
}

main().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
