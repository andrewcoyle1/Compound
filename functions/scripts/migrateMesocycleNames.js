/**
 * migrateMesocycleNames.js
 *
 * Moves training data to the periodisation names the app now uses:
 *   - users/{uid}/training_programs/{id}  →  users/{uid}/mesocycles/{id}      (copied as is)
 *   - users/{uid}/training_plans/{id}     →  users/{uid}/macrocycles/{id}     (copied, with
 *       program_ids → mesocycle_ids, block_index → mesocycle_index,
 *       block_started_at → mesocycle_started_at, and skips[].block_index → mesocycle_index)
 *   - users/{uid}/workout_sessions/{id}   training_program_id → mesocycle_id
 *   - users/{uid}                         submitted_active_training_program_id →
 *                                         submitted_active_mesocycle_id
 *   - shares/{id}                         kind "program" → "mesocycle"
 *
 * Copies only: the old collections and fields stay as a backup, so the old app keeps working and
 * the migration can be re-run. Pass --delete-old once the new build is in use to remove them.
 * Safe to run more than once: a document already in the new place is overwritten with the same
 * data, and a field already renamed is left alone.
 *
 * Usage:
 *   node scripts/migrateMesocycleNames.js --project <projectId> [--dry-run] [--delete-old]
 *
 * Auth:
 *   Uses Application Default Credentials. Run `gcloud auth application-default login` first, or
 *   set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON path.
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const deleteOld = args.includes("--delete-old");
const projectFlagIdx = args.indexOf("--project");
const projectId =
  projectFlagIdx !== -1
    ? args[projectFlagIdx + 1]
    : process.env.GCLOUD_PROJECT ?? process.env.FIREBASE_PROJECT;

if (!projectId) {
  console.error("ERROR: Supply a project ID via --project <id> or the GCLOUD_PROJECT env var.");
  process.exit(1);
}

console.log(`Project    : ${projectId}`);
console.log(`Dry run    : ${dryRun}`);
console.log(`Delete old : ${deleteOld}`);
console.log("─".repeat(50));

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const writer = db.bulkWriter();
const counts = {
  mesocycles: 0, macrocycles: 0, sessions: 0, users: 0, shares: 0, deletedDocs: 0,
};

function write(op, ref, data) {
  if (dryRun) return;
  if (op === "set") writer.set(ref, data);
  else if (op === "update") writer.update(ref, data);
  else if (op === "delete") writer.delete(ref);
}

/** The macrocycle document under its new field names. */
function renamedMacrocycle(data) {
  const out = { ...data };
  const moves = [
    ["program_ids", "mesocycle_ids"],
    ["block_index", "mesocycle_index"],
    ["block_started_at", "mesocycle_started_at"],
  ];
  for (const [from, to] of moves) {
    if (from in out) {
      if (!(to in out)) out[to] = out[from];
      delete out[from];
    }
  }
  if (Array.isArray(out.skips)) {
    out.skips = out.skips.map((skip) => {
      const s = { ...skip };
      if ("block_index" in s) {
        if (!("mesocycle_index" in s)) s.mesocycle_index = s.block_index;
        delete s.block_index;
      }
      return s;
    });
  }
  return out;
}

async function copyCollection(userRef, from, to, transform, counter) {
  const snap = await userRef.collection(from).get();
  for (const doc of snap.docs) {
    write("set", userRef.collection(to).doc(doc.id), transform(doc.data()));
    counts[counter] += 1;
    if (deleteOld) {
      write("delete", doc.ref);
      counts.deletedDocs += 1;
    }
  }
}

async function migrateUser(userDoc) {
  const userRef = userDoc.ref;
  await copyCollection(userRef, "training_programs", "mesocycles", (d) => d, "mesocycles");
  await copyCollection(userRef, "training_plans", "macrocycles", renamedMacrocycle, "macrocycles");

  const sessions = await userRef.collection("workout_sessions").get();
  for (const doc of sessions.docs) {
    const data = doc.data();
    if (!("training_program_id" in data)) continue;
    const update = {};
    if (!("mesocycle_id" in data)) update.mesocycle_id = data.training_program_id;
    if (deleteOld) update.training_program_id = FieldValue.delete();
    if (Object.keys(update).length === 0) continue;
    write("update", doc.ref, update);
    counts.sessions += 1;
  }

  const user = userDoc.data();
  if ("submitted_active_training_program_id" in user) {
    const update = {};
    if (!("submitted_active_mesocycle_id" in user)) {
      update.submitted_active_mesocycle_id = user.submitted_active_training_program_id;
    }
    if (deleteOld) update.submitted_active_training_program_id = FieldValue.delete();
    if (Object.keys(update).length > 0) {
      write("update", userRef, update);
      counts.users += 1;
    }
  }
}

async function main() {
  const users = await db.collection("users").get();
  console.log(`Users: ${users.size}`);
  for (const userDoc of users.docs) {
    await migrateUser(userDoc);
  }

  const shares = await db.collection("shares").where("kind", "==", "program").get();
  for (const doc of shares.docs) {
    write("update", doc.ref, { kind: "mesocycle" });
    counts.shares += 1;
  }

  await writer.close();
  console.log("─".repeat(50));
  console.log(dryRun ? "Would write:" : "Wrote:");
  console.log(`  mesocycles copied      : ${counts.mesocycles}`);
  console.log(`  macrocycles copied     : ${counts.macrocycles}`);
  console.log(`  sessions updated       : ${counts.sessions}`);
  console.log(`  user documents updated : ${counts.users}`);
  console.log(`  shares updated         : ${counts.shares}`);
  if (deleteOld) console.log(`  old documents deleted  : ${counts.deletedDocs}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
