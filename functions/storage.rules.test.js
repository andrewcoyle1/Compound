// Firebase Storage security rules (../storage.rules), with the paths both apps upload to.
// Needs the Storage and Firestore emulators: run `npm run test:storage-rules`.
// Plain `npm test` also picks this file up; without the emulator hosts it skips itself.
import { test, before, beforeEach, after } from "node:test";
import { readFileSync } from "node:fs";
import {
    initializeTestEnvironment, assertSucceeds, assertFails,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";

const skip = !(process.env.FIREBASE_STORAGE_EMULATOR_HOST && process.env.FIRESTORE_EMULATOR_HOST)
    && "Storage and Firestore emulators not running; run npm run test:storage-rules";

let env;
const ALICE = "alice", BOB = "bob";
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const asJpeg = { contentType: "image/jpeg" };

const storage = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();
const ref = (uid, path) => storage(uid).ref(path);
const upload = (uid, path, meta = asJpeg, bytes = JPEG) => ref(uid, path).put(bytes, meta).then((s) => s);
const read = (uid, path) => ref(uid, path).getMetadata();
const remove = (uid, path) => ref(uid, path).delete();
const list = (uid, path) => ref(uid, path).listAll();
const seedFile = (path) => env.withSecurityRulesDisabled((ctx) => ctx.storage().ref(path).put(JPEG, asJpeg).then((s) => s));
const seedDoc = (path, data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

before(async () => {
    if (skip) return;
    env = await initializeTestEnvironment({
        projectId: "demo-dialedin",
        storage: { rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8") },
        firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
    });
});
beforeEach(async () => {
    if (skip) return;
    await env.clearStorage();
    await env.clearFirestore();
});
after(async () => { if (env) await env.cleanup(); });

const t = (name, fn) => test(name, { skip }, fn);

// ---------------- USERS ----------------

const PHOTO = `users/${ALICE}/progress_photos/p1.jpg`;

t("users: the owner uploads, replaces, reads, lists and deletes their own files", async () => {
    for (const path of [PHOTO, `users/${ALICE}/profile`, `users/${ALICE}/gymProfiles/g1`, `users/${ALICE}/workout_templates/w1`]) {
        await assertSucceeds(upload(ALICE, path));
        await assertSucceeds(upload(ALICE, path));
        await assertSucceeds(read(ALICE, path));
    }
    await assertSucceeds(list(ALICE, `users/${ALICE}/progress_photos`));
    await assertSucceeds(remove(ALICE, PHOTO));
});

t("users: nobody else reads, lists, uploads to or deletes them", async () => {
    await seedFile(PHOTO);
    await assertFails(read(BOB, PHOTO));
    await assertFails(read(null, PHOTO));
    await assertFails(list(BOB, `users/${ALICE}/progress_photos`));
    await assertFails(list(null, `users/${ALICE}`));
    await assertFails(upload(BOB, PHOTO));
    await assertFails(upload(null, PHOTO));
    await assertFails(remove(BOB, PHOTO));
    await assertFails(remove(null, PHOTO));
});

t("users: a profile picture is readable by path to anyone signed in", async () => {
    await seedFile(`users/${ALICE}/profile`);
    await assertSucceeds(read(BOB, `users/${ALICE}/profile`));
    await assertFails(read(null, `users/${ALICE}/profile`));
    await assertFails(upload(BOB, `users/${ALICE}/profile`));
});

t("users: only images under 10 MB", async () => {
    await assertFails(upload(ALICE, PHOTO, { contentType: "text/plain" }));
    await assertFails(upload(ALICE, PHOTO, asJpeg, new Uint8Array(10 * 1024 * 1024)));
});

// ---------------- SHARED PHOTOS ----------------

for (const [folder, collection] of [
    ["exercises", "exercise_templates"],
    ["ingredient_templates", "ingredient_templates"],
    ["recipe_templates", "recipe_templates"],
]) {
    const path = `${folder}/x1`;

    t(`${folder}: uploading before the document exists, then replacing and deleting`, async () => {
        await assertSucceeds(upload(ALICE, path));
        await seedDoc(`${collection}/x1`, { author_id: ALICE });
        await assertSucceeds(upload(ALICE, path));
        await assertSucceeds(remove(ALICE, path));
    });

    t(`${folder}: a private item, with no top-level document, stays writable`, async () => {
        await seedDoc(`users/${ALICE}/foods/x1`, { author_id: ALICE });
        await assertSucceeds(upload(ALICE, path));
        await assertSucceeds(upload(ALICE, path));
        await assertSucceeds(remove(ALICE, path));
    });

    t(`${folder}: another author's photo can't be replaced or deleted`, async () => {
        await seedDoc(`${collection}/x1`, { author_id: ALICE });
        await seedFile(path);
        await assertFails(upload(BOB, path));
        await assertFails(remove(BOB, path));
        await assertSucceeds(read(BOB, path));
    });

    t(`${folder}: signed-out users can't read or write; only images`, async () => {
        await seedFile(path);
        await assertFails(read(null, path));
        await assertFails(upload(null, path));
        await assertFails(remove(null, path));
        await assertFails(upload(ALICE, `${folder}/x2`, { contentType: "application/pdf" }));
    });
}

// ---------------- EVERYTHING ELSE ----------------

t("other paths are closed, including the old template folders", async () => {
    for (const path of ["anything/else.jpg", "exercise_templates/e1/a.jpg", "workout_templates/w1/a.jpg", "gym_profiles/g1/a.jpg", "root.jpg"]) {
        await assertFails(upload(ALICE, path));
        await assertFails(read(ALICE, path));
    }
});
