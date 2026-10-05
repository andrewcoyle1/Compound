# AI Coach

A chat in which the user asks about their own training, nutrition and body data. Agreed
5 Oct 2026; to be built after the Today redesign.

## Decisions

| Question | Decision |
|---|---|
| Scope at launch | Read-only. It answers; it never writes. Actions (log a meal, swap an exercise) are v2, behind confirmation cards. |
| Access | Premium only, checked on the server. |
| Model | Gemini 2.5 Flash on Vertex AI, through Genkit, as the existing callables use. |
| Region | `europe-west4` for the function and the Vertex endpoint. Firestore is `eur3`, so nothing leaves the EU. |
| Data access | Server-side tools. The function reads Firestore with the Admin SDK for the caller's uid; no round trips through the app. |
| Derived figures | Ported to the server (expenditure, weight trend, PRs and e1RM, muscle volume). See "Keeping the maths in step". |
| Premium check | RevenueCat REST API v2 (`GET /v2/projects/{project_id}/customers/{uid}/active_entitlements`), any active entitlement, cached briefly. The key is a V2 secret key with only *Customer information: read* permission, held in the `REVENUECAT_SECRET_KEY` Functions secret; a V1 key would have full write access to the account. The dev project skips the check, as dev builds do. |
| History | Saved under `users/{uid}/coach_chats`, deletable per chat, removed by `onUserDeleted`. |
| Limit | 50 messages per user per day, counted in Firestore by the function, plus a burst limit. |
| Entry points | A coach button on Today's toolbar, and "Ask about this" on the weight trend, exercise history and check-in. No new tab. |

## What the model may read

- Workout sessions, templates, mesocycles and macrocycles, exercises (user and built-in)
- Meal logs, foods, recipes, diet plan and targets, check-in records, nutrition strategy settings
- Body measurements and goals
- Steps
- Session, exercise and meal notes

## What it must never read

- **Progress photos.**
- **Other people's data**: followers, following, circle, the feed, comments, likes, challenges.
- **Strava activities** (`users/{uid}/strava_activities`). Strava's API agreement forbids using its
  data with AI models. Workouts Compound uploaded to Strava are Compound's own sessions and are
  fine; anything imported from Strava is not.
- Auth, purchase and device details beyond the premium yes/no.

Each tool reads one named collection under the caller's uid. There is no generic "read any path"
tool, so the exclusions hold by construction rather than by prompt.

## Consent

- A consent screen before first use. It names Google (Vertex AI) as the provider, lists what is
  shared, and says that it never includes Strava data or photos. This is App Store guideline
  5.1.2(i): explicit permission before sharing personal data with third-party AI.
- Consent is stored on the user and can be withdrawn in Settings, which also deletes the chats.
- The privacy policy gains an AI section. Health-derived data (steps, Health weights) is never
  used for ads or analytics. Under GDPR it is special-category data, and this consent is the
  explicit consent.

## Behaviour

- Numbers come from tools, never the model's guesswork, and answers say what they are based on
  ("your last 4 bench sessions").
- It respects the calorie floor the app enforces and gives no advice below it. Injuries, pain and
  medical questions go to a professional.
- Replies stream.

## Keeping the maths in step

Expenditure, trend, PR and muscle-volume logic will exist in Swift and in JS. To stop them
drifting, a Swift test writes golden input/output fixtures (JSON) that a `node:test` case replays
against the JS port, and CI runs both. A change to either side that breaks agreement fails the
build.

## Evaluation

A set of questions against fixture accounts (cutting, bulking, stalled, new user, no plan), each
with the figures a correct answer must quote. It runs before release and on prompt or model
changes.
