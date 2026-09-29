import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getMessaging } from "firebase-admin/messaging";
import {
    requireAuth, cleanJson, normaliseName, buildActivityPush, newlyBlockedIds, pushRecipientSettings,
    planFollowAccepted, buildFollowAcceptedNotification,
    buildFollowRequestPush, removedFollowingIds, planAutoAccept, removeFollowerTarget,
    buildStreakReminderPush, isStreakReminderDue, isWeeklyDigestDue, digestWindowStart, countTrainingSessions, buildWeeklyDigestPush,
    isNudgeOnCooldown, toDate,
} from "./lib.js";
import { genkit } from "genkit";
import { vertexAI, gemini20Flash, imagen3Fast } from "@genkit-ai/vertexai";

initializeApp();

const PROJECT_ID = "dialed-c3cb5";
const REGION = "us-central1";

// Every callable requires a valid App Check token, so only genuine app instances
// (attested via App Attest, or an allowlisted debug token) can invoke them. These
// functions spend Vertex AI quota and write with Admin SDK privileges, which bypass
// Firestore rules, so they cannot be left open to arbitrary HTTPS callers.
const CALLABLE_OPTIONS = { region: REGION, enforceAppCheck: true };


// ---------------------------------------------------------------------------
// Genkit / Firebase AI Logic setup
// ---------------------------------------------------------------------------

const ai = genkit({
    plugins: [vertexAI({ projectId: PROJECT_ID, location: REGION })],
});


async function findOrCreateIngredient(uid, item) {
    const db = getFirestore();
    const collectionRef = db.collection("users").doc(uid).collection("ingredient_templates");
    const nameLower = normaliseName(item.name);

    // Primary: name_lower field (on all docs created by this function)
    const primarySnap = await collectionRef.where("name_lower", "==", nameLower).limit(1).get();
    if (!primarySnap.empty) return primarySnap.docs[0].data().ingredient_id;

    // Fallback: exact name match (handles legacy docs without name_lower)
    const fallbackSnap = await collectionRef.where("name", "==", item.name.trim()).limit(1).get();
    if (!fallbackSnap.empty) return fallbackSnap.docs[0].data().ingredient_id;

    // Not found — create new ingredient (nutrition per 100g)
    const ingredientId = collectionRef.doc().id;
    const amountGrams = item.amountGrams > 0 ? item.amountGrams : 100;
    const per100g = (v) => (v != null ? (v / amountGrams) * 100 : null);
    const now = new Date();

    await collectionRef.doc(ingredientId).set({
        ingredient_id: ingredientId,
        author_id: uid,
        name: item.name.trim(),
        name_lower: nameLower,
        brand_name: null,
        description: null,
        measurement_method: "weight",
        calories: per100g(item.calories ?? null),
        protein: per100g(item.proteinGrams ?? null),
        carbs: per100g(item.carbGrams ?? null),
        fat_total: per100g(item.fatGrams ?? null),
        date_created: now,
        date_modified: now,
    });

    console.log(`Created ingredient "${item.name}" (id=${ingredientId}) for user ${uid}`);
    return ingredientId;
}

// Prompts shared across food-analysis functions
const FOOD_ITEMS_SCHEMA = `{
  "items": [
    {
      "id": "1",
      "name": "Food name",
      "amountGrams": 150,
      "calories": 248,
      "proteinGrams": 46.5,
      "carbGrams": 0,
      "fatGrams": 5.4
    }
  ]
}`;

const FOOD_LABEL_SCHEMA = `{
  "name": "Product Name",
  "measurementMethod": "weight",
  "calories": 380,
  "protein": 30.0,
  "carbs": 45.0,
  "fatTotal": 5.0,
  "fatSaturated": 1.5,
  "fiber": 3.0,
  "sugar": 8.0,
  "sodiumMg": 250,
  "potassiumMg": 420,
  "calciumMg": 200,
  "ironMg": 2.5
}`;

// ---------------------------------------------------------------------------
// AI: Analyse food from a photo
// ---------------------------------------------------------------------------

export const foodAnalyze = onCall(CALLABLE_OPTIONS, async (request) => {
    const uid = requireAuth(request);
    const { imageBase64 } = request.data;
    if (!imageBase64 || typeof imageBase64 !== "string") {
        throw new HttpsError("invalid-argument", "imageBase64 is required");
    }

    const systemPrompt = `You are a nutrition expert. Analyse the food in the image.
Return ONLY valid JSON matching this exact schema — no markdown fences, no extra text:
${FOOD_ITEMS_SCHEMA}
Include every distinct food item visible. Estimate realistic portion sizes in grams and
calculate macronutrients per portion. All numeric fields must be numbers, not strings.`;

    const { text } = await ai.generate({
        model: gemini20Flash,
        prompt: [
            {
                media: {
                    url: `data:image/jpeg;base64,${imageBase64}`,
                    contentType: "image/jpeg",
                },
            },
            { text: systemPrompt },
        ],
        config: { responseMimeType: "application/json" },
    });

    const parsed = JSON.parse(cleanJson(text));

    if (Array.isArray(parsed.items)) {
        const resolvedItems = await Promise.all(
            parsed.items.map(async (item) => ({
                ...item,
                ingredientId: await findOrCreateIngredient(uid, item),
            }))
        );
        return { result: JSON.stringify({ items: resolvedItems }) };
    }

    return { result: cleanJson(text) };
});

// ---------------------------------------------------------------------------
// AI: Describe a meal in plain text → structured food items
// ---------------------------------------------------------------------------

export const mealDescribe = onCall(CALLABLE_OPTIONS, async (request) => {
    const uid = requireAuth(request);
    const { description } = request.data;
    if (!description || typeof description !== "string" || description.trim().length === 0) {
        throw new HttpsError("invalid-argument", "description is required");
    }

    const prompt = `You are a nutrition expert. The user described their meal as:
"${description.trim()}"

Break it down into individual food components and return ONLY valid JSON matching this exact
schema — no markdown fences, no extra text:
${FOOD_ITEMS_SCHEMA}
Estimate realistic portion sizes in grams and calculate macronutrients per component.
All numeric fields must be numbers, not strings.`;

    const { text } = await ai.generate({
        model: gemini20Flash,
        prompt,
        config: { responseMimeType: "application/json" },
    });

    const parsed = JSON.parse(cleanJson(text));

    if (Array.isArray(parsed.items)) {
        const resolvedItems = await Promise.all(
            parsed.items.map(async (item) => ({
                ...item,
                ingredientId: await findOrCreateIngredient(uid, item),
            }))
        );
        return { result: JSON.stringify({ items: resolvedItems }) };
    }

    return { result: cleanJson(text) };
});

// ---------------------------------------------------------------------------
// AI: Extract structured data from a nutrition label
// ---------------------------------------------------------------------------

export const nutritionLabelAnalyze = onCall(CALLABLE_OPTIONS, async (request) => {
    requireAuth(request);
    const { labelText } = request.data;
    if (!labelText || typeof labelText !== "string" || labelText.trim().length === 0) {
        throw new HttpsError("invalid-argument", "labelText is required");
    }

    const prompt = `You are a nutrition expert. Extract all nutrition information from the
following label text and return ONLY valid JSON matching this exact schema — no markdown
fences, no extra text:
${FOOD_LABEL_SCHEMA}
Use null for any field that is not present in the label.
measurementMethod should be "weight" (per grams) or "volume" (per mL).
All numeric values must be numbers, not strings.

Label text:
${labelText.trim()}`;

    const { text } = await ai.generate({
        model: gemini20Flash,
        prompt,
        config: { responseMimeType: "application/json" },
    });

    return { result: cleanJson(text) };
});

// ---------------------------------------------------------------------------
// AI: General chat (Gemini)
// ---------------------------------------------------------------------------

export const chatGenerate = onCall(CALLABLE_OPTIONS, async (request) => {
    requireAuth(request);
    const { messages, temperature = 0.7, maxOutputTokens = 512 } = request.data;
    if (!Array.isArray(messages) || messages.length === 0) {
        throw new HttpsError("invalid-argument", "messages array is required");
    }

    // Build Genkit message history
    const history = messages.slice(0, -1).map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        content: [{ text: m.message }],
    }));
    const last = messages[messages.length - 1];

    const { text } = await ai.generate({
        model: gemini20Flash,
        messages: history,
        prompt: last.message,
        config: { temperature, maxOutputTokens },
    });

    return { role: "assistant", message: text.trim() };
});

// ---------------------------------------------------------------------------
// AI: Image generation (Imagen 3 via Vertex AI)
// ---------------------------------------------------------------------------

export const imageGenerate = onCall(CALLABLE_OPTIONS, async (request) => {
    requireAuth(request);
    const { prompt } = request.data;
    if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
        throw new HttpsError("invalid-argument", "prompt is required");
    }

    const response = await ai.generate({
        model: imagen3Fast,
        prompt: prompt.trim(),
        output: { format: "media" },
    });

    const mediaUrl = response.media?.url;
    if (!mediaUrl) {
        throw new HttpsError("internal", "No image returned from Imagen");
    }

    // mediaUrl is a data URI: "data:image/png;base64,<base64>"
    const base64 = mediaUrl.split(",")[1];
    return { base64 };
});

// ---------------------------------------------------------------------------
// Food search (proxies Open Food Facts with Firestore caching)
// ---------------------------------------------------------------------------

const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

export const foodSearch = onCall(CALLABLE_OPTIONS, async (request) => {
    requireAuth(request);
    const query = request.data.query;
    if (!query || typeof query !== "string" || query.trim().length === 0) {
        throw new HttpsError("invalid-argument", "query is required");
    }

    const trimmed = query.trim();
    const db = getFirestore();
    const cacheKey = trimmed.toLowerCase().replace(/\s+/g, "_");
    const cacheRef = db.collection("food_search_cache").doc(cacheKey);

    // Check cache
    const cached = await cacheRef.get();
    if (cached.exists) {
        const data = cached.data();
        const age = Date.now() - data.cachedAt.toMillis();
        if (age < CACHE_TTL_MS) {
            cacheRef.update({ hitCount: FieldValue.increment(1) });
            console.log(`Cache HIT: "${trimmed}" (${data.products.length} results, age=${Math.round(age / 3600000)}h)`);
            return { products: data.products };
        }
    }

    const url = new URL("https://world.openfoodfacts.org/api/v2/search");
    url.searchParams.set("search_terms", trimmed);
    url.searchParams.set("fields", "product_name,brands,nutriments,serving_size,serving_quantity,image_front_small_url");
    url.searchParams.set("page_size", "50");
    url.searchParams.set("sort_by", "unique_scans_n");

    let response;
    try {
        response = await fetch(url.toString(), {
            headers: { "User-Agent": "DialedIn/1.0 (nutrition tracking app; contact@dialedinapp.com)" },
        });
    } catch (err) {
        throw new HttpsError("unavailable", `Network error reaching Open Food Facts: ${err.message}`);
    }

    if (!response.ok) {
        throw new HttpsError("unavailable", `Open Food Facts returned HTTP ${response.status}`);
    }

    const queryWords = trimmed.toLowerCase().split(/\s+/).filter((w) => w.length > 1);
    const isRelevant = (name) => {
        if (queryWords.length === 0) return true;
        const lower = name.toLowerCase();
        return queryWords.some((w) => lower.includes(w));
    };

    const json = await response.json();
    const products = (json.products ?? [])
        .filter((p) => p.product_name && p.product_name.trim().length > 0)
        .filter((p) => isRelevant(p.product_name))
        .slice(0, 20)
        .map((p) => ({
            name: p.product_name.trim(),
            brandName: p.brands ?? null,
            imageURL: p.image_front_small_url ?? null,
            servingWeight: p.serving_quantity ?? null,
            servingSize: p.serving_size ?? null,
            calories: p.nutriments?.["energy-kcal_100g"] ?? null,
            protein: p.nutriments?.["proteins_100g"] ?? null,
            carbs: p.nutriments?.["carbohydrates_100g"] ?? null,
            fatTotal: p.nutriments?.["fat_100g"] ?? null,
            fatSaturated: p.nutriments?.["saturated-fat_100g"] ?? null,
            fiber: p.nutriments?.["fiber_100g"] ?? null,
            sugar: p.nutriments?.["sugars_100g"] ?? null,
            sodiumMg: p.nutriments?.["sodium_100g"] != null
                ? p.nutriments["sodium_100g"] * 1000
                : null,
            potassiumMg: p.nutriments?.["potassium_100g"] ?? null,
            calciumMg: p.nutriments?.["calcium_100g"] ?? null,
            ironMg: p.nutriments?.["iron_100g"] ?? null,
            vitaminAMcg: p.nutriments?.["vitamin-a_100g"] ?? null,
            vitaminB6Mg: p.nutriments?.["vitamin-b6_100g"] ?? null,
            vitaminB12Mcg: p.nutriments?.["vitamin-b12_100g"] ?? null,
            vitaminCMg: p.nutriments?.["vitamin-c_100g"] ?? null,
            vitaminDMcg: p.nutriments?.["vitamin-d_100g"] ?? null,
            vitaminEMg: p.nutriments?.["vitamin-e_100g"] ?? null,
            vitaminKMcg: p.nutriments?.["vitamin-k_100g"] ?? null,
            magnesiumMg: p.nutriments?.["magnesium_100g"] ?? null,
            zincMg: p.nutriments?.["zinc_100g"] ?? null,
            phosphorusMg: p.nutriments?.["phosphorus_100g"] ?? null,
            cholesterolMg: p.nutriments?.["cholesterol_100g"] ?? null,
            caffeineMg: p.nutriments?.["caffeine_100g"] ?? null,
            riboflavinMg: p.nutriments?.["riboflavin_100g"] ?? null,
            thiaminMg: p.nutriments?.["thiamin_100g"] ?? null,
            niacinMg: p.nutriments?.["niacin_100g"] ?? null,
            biotinMcg: p.nutriments?.["biotin_100g"] ?? null,
            folateMcg: p.nutriments?.["folates_100g"] ?? null,
            iodineMcg: p.nutriments?.["iodine_100g"] ?? null,
            seleniumMcg: p.nutriments?.["selenium_100g"] ?? null,
            manganeseMg: p.nutriments?.["manganese_100g"] ?? null,
            copperMg: p.nutriments?.["copper_100g"] ?? null,
            chlorideMg: p.nutriments?.["chloride_100g"] ?? null,
            pantothenicAcidMg: p.nutriments?.["pantothenic-acid_100g"] ?? null,
        }));

    cacheRef.set({
        query: trimmed,
        products,
        cachedAt: FieldValue.serverTimestamp(),
        hitCount: 0,
    });

    console.log(`Cache MISS: "${trimmed}" — fetched ${products.length} from OFF`);
    return { products };
});

// ---------------------------------------------------------------------------
// FCM push for social activity (likes / comments / mentions / follows / nudges)
// ---------------------------------------------------------------------------

// The app writes users/{uid}/notifications for the in-app bell; this turns each new doc into a
// push so it still arrives when the app is closed. The token and opt-outs are private to the owner,
// in users/{uid}/private/settings; pushRecipientSettings falls back to the legacy user-doc fields.
// Message building and the opt-out check live in lib.js so they can be tested without Firestore.
export const onActivityNotificationCreated = onDocumentCreated(
    { document: "users/{userId}/notifications/{notificationId}", region: REGION },
    async (event) => {
        const notification = event.data?.data();
        if (!notification) return;

        const userId = event.params.userId;
        const userRef = getFirestore().collection("users").doc(userId);
        if (notification.type === "nudge" && await nudgeOnCooldown(userRef, event.data, notification)) {
            await event.data.ref.delete();
            console.log(`Nudge from ${notification.actor_id} to ${userId} dropped: cooldown.`);
            return;
        }
        const [userDoc, privateDoc] = await Promise.all([
            userRef.get(),
            userRef.collection("private").doc("settings").get(),
        ]);
        const recipient = pushRecipientSettings(privateDoc.data(), userDoc.data());
        const message = buildActivityPush(notification, recipient);
        if (!message) {
            console.log(`No push for user ${userId} (${notification.type}): no token or opted out.`);
            return;
        }

        try {
            await getMessaging().send(message);
        } catch (error) {
            console.error(`Error sending push to user ${userId}: ${error.message}`);
        }
    }
);

// ---------------------------------------------------------------------------
// Blocking: end the blocked person's follow
// ---------------------------------------------------------------------------

// A follow lives in the follower's own following_ids, which the blocker cannot write and rules
// cannot refuse on the blocker's behalf. So when users/{uid}.blocked_user_ids gains an id, this
// takes uid out of that person's following_ids and drops any pending follow request they sent.
// The blocked person's document changing re-fires this trigger, but their block list is unchanged,
// so it returns at once.
export const onUserBlockListChanged = onDocumentUpdated(
    { document: "users/{uid}", region: REGION },
    async (event) => {
        const blocked = newlyBlockedIds(event.data?.before?.data(), event.data?.after?.data());
        if (blocked.length === 0) return;

        const uid = event.params.uid;
        const users = getFirestore().collection("users");
        const results = await Promise.allSettled(blocked.flatMap((blockedId) => [
            // update, not set: a deleted account must not come back as a stub document.
            users.doc(blockedId).update({ following_ids: FieldValue.arrayRemove(uid) }),
            // A no-op when there is no request, or no follow_requests collection at all.
            users.doc(uid).collection("follow_requests").doc(blockedId).delete(),
        ]));
        for (const result of results) {
            if (result.status === "rejected") {
                console.error(`Block cleanup for user ${uid}: ${result.reason?.message}`);
            }
        }
    }
);

// ---------------------------------------------------------------------------
// Follow requests to private profiles
// ---------------------------------------------------------------------------

// The target of a request accepts it by setting status to "accepted", but a client can only write
// its own users/{uid} document, so the follow itself is written here: the target joins the
// requester's following_ids, the requester gets a followAccepted notification (which
// onActivityNotificationCreated turns into a push), and the request is deleted. A declined request
// is left for the requester to see as declined; nothing else happens.
export const onFollowRequestUpdated = onDocumentUpdated(
    { document: "users/{targetId}/follow_requests/{requesterId}", region: REGION },
    async (event) => {
        const plan = planFollowAccepted(event.data?.before?.data(), event.data?.after?.data(), event.params);
        if (!plan) return;

        const db = getFirestore();
        const targetDoc = await db.collection("users").doc(plan.targetId).get();
        const batch = db.batch();
        batch.update(db.collection("users").doc(plan.requesterId), {
            following_ids: FieldValue.arrayUnion(plan.targetId),
        });
        batch.set(
            db.collection("users").doc(plan.requesterId).collection("notifications").doc(plan.notificationId),
            buildFollowAcceptedNotification(targetDoc.data(), plan)
        );
        batch.delete(event.data.after.ref);
        await batch.commit();
    }
);

// ---------------------------------------------------------------------------
// Follow requests, live: push, removing a follower, cleanup and auto-accept
// ---------------------------------------------------------------------------

// A new request pushes "<Name> wants to follow you" to the target, under the follows preference.
// The payload's type is follow_request, which the app opens on its notifications screen.
export const onFollowRequestCreated = onDocumentCreated(
    { document: "users/{targetId}/follow_requests/{requesterId}", region: REGION },
    async (event) => {
        const request = event.data?.data();
        if (!request) return;

        const targetId = event.params.targetId;
        const userRef = getFirestore().collection("users").doc(targetId);
        const [userDoc, privateDoc] = await Promise.all([
            userRef.get(),
            userRef.collection("private").doc("settings").get(),
        ]);
        const message = buildFollowRequestPush(request, pushRecipientSettings(privateDoc.data(), userDoc.data()), userDoc.data());
        if (!message) return;

        try {
            await getMessaging().send(message);
        } catch (error) {
            console.error(`Error sending follow request push to user ${targetId}: ${error.message}`);
        }
    }
);

// A follow lives in the follower's own following_ids, which the person followed cannot write, so
// removing a follower comes through here. The follow notification it left in the caller's bell goes
// too. There is no follower count stored anywhere to decrement.
export const removeFollower = onCall(CALLABLE_OPTIONS, async (request) => {
    const uid = requireAuth(request);
    const followerId = removeFollowerTarget(request.data, uid);
    if (!followerId) {
        throw new HttpsError("invalid-argument", "followerId is required");
    }

    const users = getFirestore().collection("users");
    try {
        // update, not set: a deleted account must not come back as a stub document.
        await users.doc(followerId).update({ following_ids: FieldValue.arrayRemove(uid) });
    } catch (error) {
        if (error.code !== 5) throw error; // 5 = NOT_FOUND: the follower's account is gone already.
    }
    await users.doc(uid).collection("notifications").doc(`follow_${followerId}`).delete();
    return { removed: followerId };
});

// When following_ids loses an id (an unfollow, a block, or removeFollower), any pending request
// between the pair is deleted, in both directions.
export const onUserFollowingChanged = onDocumentUpdated(
    { document: "users/{uid}", region: REGION },
    async (event) => {
        const removed = removedFollowingIds(event.data?.before?.data(), event.data?.after?.data());
        if (removed.length === 0) return;

        const uid = event.params.uid;
        const users = getFirestore().collection("users");
        const results = await Promise.allSettled(removed.flatMap((otherId) => [
            users.doc(otherId).collection("follow_requests").doc(uid).delete(),
            users.doc(uid).collection("follow_requests").doc(otherId).delete(),
        ]));
        for (const result of results) {
            if (result.status === "rejected") {
                console.error(`Follow request cleanup for user ${uid}: ${result.reason?.message}`);
            }
        }
    }
);

// A profile going from private to public accepts every pending request, as Instagram does. Each
// becomes an ordinary acceptance, so onFollowRequestUpdated writes the follow and the notification.
export const onUserPrivacyChanged = onDocumentUpdated(
    { document: "users/{uid}", region: REGION },
    async (event) => {
        const before = event.data?.before?.data();
        const after = event.data?.after?.data();
        if (!planAutoAccept(before, after, [])) return;

        const requestsRef = getFirestore().collection("users").doc(event.params.uid).collection("follow_requests");
        const pending = await requestsRef.where("status", "==", "pending").get();
        const accept = planAutoAccept(before, after, pending.docs.map((doc) => ({ id: doc.id, data: doc.data() })));

        // A batch takes at most 500 writes.
        for (let start = 0; start < accept.length; start += 500) {
            const batch = getFirestore().batch();
            for (const requesterId of accept.slice(start, start + 500)) {
                batch.update(requestsRef.doc(requesterId), { status: "accepted" });
            }
            await batch.commit();
        }
    }
);

// ---------------------------------------------------------------------------
// Usernames
// ---------------------------------------------------------------------------

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { planUsernameRelease, shouldReleaseReservation } from "./lib.js";

// The app reserves usernames/{handle} before setting users/{uid}.username, and rules only let the
// owner delete a reservation. When a username changes, or the account is deleted, the old handle is
// released here so someone else can claim it. Written, not just updated, so deletion is covered too.
export const onUsernameChanged = onDocumentWritten(
    { document: "users/{uid}", region: REGION },
    async (event) => {
        const handle = planUsernameRelease(event.data?.before?.data(), event.data?.after?.data());
        if (!handle) return;

        const db = getFirestore();
        const ref = db.collection("usernames").doc(handle);
        await db.runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (snap.exists && shouldReleaseReservation(snap.data(), event.params.uid)) {
                tx.delete(ref);
            }
        });
    }
);

// Scheduled pushes: nudge cooldown, streak reminder, Sunday digest
// ---------------------------------------------------------------------------

// Whether the same actor nudged this recipient within 24 hours before this nudge. Queries on
// actor_id alone (a single-field index) and filters the type here.
async function nudgeOnCooldown(userRef, snapshot, notification) {
    const earlier = await userRef.collection("notifications").where("actor_id", "==", notification.actor_id).get();
    const latest = earlier.docs
        .filter((doc) => doc.id !== snapshot.id && doc.data().type === "nudge")
        .map((doc) => toDate(doc.data().date_created))
        .filter(Boolean)
        .sort((a, b) => b - a)[0];
    return isNudgeOnCooldown(latest, toDate(notification.date_created) ?? new Date());
}

// Every users/{uid}/private/settings doc, with its uid. Both scheduled pushes run hourly and pick
// the users whose local hour matches, so each walks all of them.
// ponytail: a full scan of the private group every hour; store a UTC send hour and query on it
// once the user count makes this slow.
async function allPrivateSettings() {
    const snap = await getFirestore().collectionGroup("private").get();
    return snap.docs
        .filter((doc) => doc.id === "settings" && doc.ref.parent.parent)
        .map((doc) => ({ uid: doc.ref.parent.parent.id, settings: doc.data() }));
}

async function sendAll(label, messages) {
    const results = await Promise.allSettled(messages.map((message) => getMessaging().send(message)));
    const failed = results.filter((result) => result.status === "rejected");
    for (const result of failed) console.error(`${label} push failed: ${result.reason?.message}`);
    console.log(`${label}: sent ${messages.length - failed.length} of ${messages.length}.`);
}

// Hourly, on the hour. In each user's reminder hour (local), a user with a live streak who has not
// trained today is told it ends at midnight. The streak is StreakManager's document at
// user_streaks/{uid}/workout/current_streak (SwiftfulGamification's FirebaseRemoteStreakService).
export const streakReminder = onSchedule(
    { schedule: "0 * * * *", timeZone: "Etc/UTC", region: REGION },
    async () => {
        const now = new Date();
        const db = getFirestore();
        const messages = await Promise.all((await allPrivateSettings()).map(async ({ uid, settings }) => {
            if (!isStreakReminderDue(settings, now)) return null;
            const streak = await db.collection("user_streaks").doc(uid).collection("workout").doc("current_streak").get();
            return buildStreakReminderPush(settings, streak.data(), now);
        }));
        await sendAll("Streak reminder", messages.filter(Boolean));
    }
);

// Hourly, on the hour, sending to the users for whom it is Sunday 18:00: how many sessions they
// and the people they follow logged in the last seven days. Nobody followed, no digest.
export const weeklyDigest = onSchedule(
    { schedule: "0 * * * *", timeZone: "Etc/UTC", region: REGION },
    async () => {
        const now = new Date();
        const since = digestWindowStart(now);
        const users = getFirestore().collection("users");
        const sessionsSince = async (uid) => countTrainingSessions(
            (await users.doc(uid).collection("workout_sessions").where("date_created", ">=", since).get()).docs.map((d) => d.data())
        );
        const due = (await allPrivateSettings()).filter(({ settings }) => isWeeklyDigestDue(settings, now));
        const messages = await Promise.all(due.map(async ({ uid, settings }) => {
            const following = ((await users.doc(uid).get()).data()?.following_ids ?? []).filter((id) => id !== uid);
            if (following.length === 0) return null;
            const [mine, ...circle] = await Promise.all([uid, ...following].map(sessionsSince));
            return buildWeeklyDigestPush(settings, {
                mine, circle: circle.reduce((a, b) => a + b, 0), followingCount: following.length,
            });
        }));
        await sendAll("Weekly digest", messages.filter(Boolean));
    }
);

// Account deletion cleanup
// ---------------------------------------------------------------------------

// Imported here rather than at the top so this block merges without touching the shared import lines.
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { getStorage } from "firebase-admin/storage";
import { planUserDeletion } from "./lib.js";

// The app deletes only users/{uid} (after stopping its listeners) and then the Auth user. This removes
// everything else: every subcollection, the user's id in other people's following_ids,
// blocked_user_ids and liked_by_user_ids, their sent follow requests, comments (theirs, and others' on
// their sessions), notifications they caused, username reservations, exercises, diet plan and Storage
// uploads. What to write is decided by planUserDeletion in lib.js.
export const onUserDeleted = onDocumentDeleted(
    { document: "users/{uid}", region: REGION, timeoutSeconds: 540, memory: "512MiB" },
    async (event) => {
        const uid = event.params.uid;
        const db = getFirestore();
        const userRef = db.collection("users").doc(uid);
        const paths = (query) => query.select().get().then((snap) => snap.docs.map((doc) => doc.ref.path));
        const ids = (collection) => collection.listDocuments().then((refs) => refs.map((ref) => ref.id));

        // Everything is read before the recursive delete, which takes the recipe and food ids with it.
        const comments = db.collection("workout_session_comments");
        const [
            followers, blockers, followRequests, likedSessions, commentsByUser, commentsOnSessions,
            notifications, usernames, exercises, recipeTemplates, foods,
        ] = await Promise.all([
            paths(db.collection("users").where("following_ids", "array-contains", uid)),
            paths(db.collection("users").where("blocked_user_ids", "array-contains", uid)),
            paths(db.collectionGroup("follow_requests").where("requester_id", "==", uid)),
            paths(db.collectionGroup("workout_sessions").where("liked_by_user_ids", "array-contains", uid)),
            paths(comments.where("author_id", "==", uid)),
            paths(comments.where("session_author_id", "==", uid)),
            paths(db.collectionGroup("notifications").where("actor_id", "==", uid)),
            paths(db.collection("usernames").where("user_id", "==", uid)),
            db.collection("exercise_templates").where("author_id", "==", uid).select().get()
                .then((snap) => snap.docs.map((doc) => doc.id)),
            ids(userRef.collection("recipe_templates")),
            ids(userRef.collection("foods")),
        ]);

        await db.recursiveDelete(userRef);

        const plan = planUserDeletion(uid, {
            followers, blockers, followRequests, likedSessions,
            comments: [...commentsByUser, ...commentsOnSessions],
            notifications, usernames, exercises, recipeTemplates, foods,
        });
        for (const writes of plan.batches) {
            const batch = db.batch();
            for (const write of writes) {
                const ref = db.doc(write.path);
                if (write.type === "delete") batch.delete(ref);
                else batch.update(ref, { [write.field]: FieldValue.arrayRemove(write.value) });
            }
            try {
                await batch.commit();
            } catch (error) {
                // One document deleted meanwhile fails its batch; the others still run.
                console.error(`Account cleanup for user ${uid}: ${error.message}`);
            }
        }

        const bucket = getStorage().bucket();
        const results = await Promise.allSettled([
            ...plan.storagePrefixes.map((prefix) => bucket.deleteFiles({ prefix })),
            ...plan.storageFiles.map((file) => bucket.file(file).delete({ ignoreNotFound: true })),
        ]);
        for (const result of results) {
            if (result.status === "rejected") {
                console.error(`Storage cleanup for user ${uid}: ${result.reason?.message}`);
            }
        }
    }
);

// Report moderation
// ---------------------------------------------------------------------------

import { planReportModeration } from "./lib.js";

// A new reports/{id}: once three distinct people have open reports on the same session or comment,
// set hidden: true on it (the app then shows it only to its author) and queue it for review in
// moderation_queue/{targetId}. What to write is decided by planReportModeration in lib.js. Queries on
// target_id alone, a single-field index, and filters status and type there.
export const onReportCreated = onDocumentCreated(
    { document: "reports/{reportId}", region: REGION },
    async (event) => {
        const report = event.data?.data();
        if (!report?.target_id) return;
        const db = getFirestore();
        const snap = await db.collection("reports").where("target_id", "==", report.target_id).get();
        const plan = planReportModeration(report, snap.docs.map((doc) => doc.data()));
        if (!plan) return;

        await db.collection("moderation_queue").doc(plan.queueId).set(
            { ...plan.queue, date_updated: FieldValue.serverTimestamp() },
            { merge: true }
        );
        if (!plan.hidePath) return;
        try {
            await db.doc(plan.hidePath).update({ hidden: true });
        } catch (error) {
            // The content was deleted meanwhile, or the report named the wrong author.
            console.error(`Report moderation: could not hide ${plan.hidePath}: ${error.message}`);
        }
    }
);

// ---------------------------------------------------------------------------
// Challenges
// ---------------------------------------------------------------------------

import { sessionJustEnded, activeChallengesFor, planChallengeProgress } from "./lib.js";

// When a member finishes a session, each running challenge they are in gains one session in
// challenges/{id}/progress/{uid}, which only this function writes. Reaching the target writes a
// challenge_complete notification, which onActivityNotificationCreated turns into the push. The
// counted session ids ride along in the progress doc, so a retried trigger does not count twice.
export const onWorkoutSessionEndedForChallenges = onDocumentWritten(
    { document: "users/{uid}/workout_sessions/{sessionId}", region: REGION },
    async (event) => {
        const after = event.data?.after?.data();
        if (!sessionJustEnded(event.data?.before?.data(), after)) return;

        const { uid, sessionId } = event.params;
        const db = getFirestore();
        const snap = await db.collection("challenges").where("member_ids", "array-contains", uid).get();
        const challenges = activeChallengesFor(snap.docs.map((doc) => ({ ...doc.data(), id: doc.id })), uid, after.ended_at);
        if (challenges.length === 0) return;

        const user = (await db.collection("users").doc(uid).get()).data();
        for (const challenge of challenges) {
            const progressRef = db.collection("challenges").doc(challenge.id).collection("progress").doc(uid);
            try {
                await db.runTransaction(async (tx) => {
                    const plan = planChallengeProgress(challenge, uid, sessionId, (await tx.get(progressRef)).data(), user);
                    if (!plan) return;
                    tx.set(progressRef, plan.progress);
                    if (plan.notification) {
                        tx.set(db.collection("users").doc(uid).collection("notifications").doc(plan.notificationId), plan.notification);
                    }
                });
            } catch (error) {
                console.error(`Challenge ${challenge.id} progress for user ${uid}: ${error.message}`);
            }
        }
    }
);

// ---------------------------------------------------------------------------
// Invites
// ---------------------------------------------------------------------------

import {
    normaliseInviteCode, planInviteAcceptance, inviteOutcome, buildFollowNotification, buildInviteFollowRequest,
} from "./lib.js";

// A compound://join/<code> link or a typed code. Follows both ways between the caller and the
// inviter, as a follow request where the one to be followed is private, and counts the use. Every
// write is someone else's document at least once, so it happens here. One transaction, so two
// acceptances cannot both take the last use. Returns the inviter's id for the app to open their
// profile, and what each direction became.
export const acceptInvite = onCall(CALLABLE_OPTIONS, async (request) => {
    const uid = requireAuth(request);
    const code = normaliseInviteCode(request.data?.code);
    if (!code) throw new HttpsError("invalid-argument", "That doesn't look like an invite code.");

    const db = getFirestore();
    const users = db.collection("users");
    const inviteRef = db.collection("invites").doc(code);

    return db.runTransaction(async (tx) => {
        const inviteDoc = await tx.get(inviteRef);
        const invite = inviteDoc.data();
        const [inviterDoc, inviteeDoc] = invite
            ? await Promise.all([tx.get(users.doc(invite.inviter_id)), tx.get(users.doc(uid))])
            : [null, null];
        const plan = planInviteAcceptance({
            callerId: uid, invite, inviter: inviterDoc?.data(), invitee: inviteeDoc?.data(),
        });
        if (plan.error) throw new HttpsError(...plan.error);

        const { inviterId } = plan;
        const inviter = inviterDoc.data();
        const invitee = inviteeDoc.data();
        const now = new Date();
        const apply = (direction, followerId, follower, followedId) => {
            if (direction === "follow") {
                // update, not set: a missing user document must not come back as a stub.
                tx.update(users.doc(followerId), { following_ids: FieldValue.arrayUnion(followedId) });
                tx.set(
                    users.doc(followedId).collection("notifications").doc(`follow_${followerId}`),
                    buildFollowNotification(follower, { followerId, followedId }, now)
                );
            } else if (direction === "request") {
                tx.set(
                    users.doc(followedId).collection("follow_requests").doc(followerId),
                    buildInviteFollowRequest(follower, followerId, now)
                );
            }
        };
        apply(plan.inviteeFollows, uid, invitee, inviterId);
        apply(plan.inviterFollows, inviterId, inviter, uid);
        if (plan.countsUse) tx.update(inviteRef, { uses: FieldValue.increment(1) });

        return {
            inviter_id: inviterId,
            you_follow: inviteOutcome(plan.inviteeFollows),
            they_follow: inviteOutcome(plan.inviterFollows),
        };
    });
});

// MARK: - Web share page

import { onRequest } from "firebase-functions/v2/https";
import { buildSessionPageHtml, notFoundPageHtml, parseSessionPath } from "./lib.js";

// Hosting rewrites /s/** here (firebase.json). Public and unauthenticated by design, so it reads
// with the Admin SDK and lets buildSessionPageHtml refuse private authors and hidden sessions,
// answering every refusal with the same 404 so the page never confirms a session exists.
export const sessionPage = onRequest({ region: REGION }, async (req, res) => {
    const notFound = () => res.status(404).set("Cache-Control", "public, max-age=60").send(notFoundPageHtml());
    const ids = parseSessionPath(req.path);
    if (req.method !== "GET" && req.method !== "HEAD") return res.status(405).send("");
    if (!ids) return notFound();

    const author = getFirestore().collection("users").doc(ids.authorId);
    const [authorDoc, sessionDoc] = await Promise.all([author.get(), author.collection("workout_sessions").doc(ids.sessionId).get()]);
    const session = sessionDoc.exists ? { id: sessionDoc.id, ...sessionDoc.data() } : null;
    if (!buildSessionPageHtml({ session, author: authorDoc.data() })) return notFound();

    // Records need the author's earlier sessions, read only once the page is known to render.
    // ponytail: reads every earlier session per uncached view; stamp PR lines on the session if that bill shows up.
    const prior = await author.collection("workout_sessions").where("date_created", "<", session.date_created).get();
    const html = buildSessionPageHtml({
        session,
        author: authorDoc.data(),
        priorSessions: prior.docs.map((d) => ({ id: d.id, ...d.data() })),
        url: `https://${PROJECT_ID}.web.app/s/${ids.authorId}/${ids.sessionId}`,
    });
    // Short CDN cache: going private takes effect within ten minutes.
    res.set("Cache-Control", "public, max-age=300, s-maxage=600").send(html);
});
