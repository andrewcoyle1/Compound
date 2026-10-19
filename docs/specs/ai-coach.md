# AI Coach

A chat in which the user asks about their own training, nutrition and body data. Agreed
5 Oct 2026; to be built after the Today redesign.

## Decisions

| Question | Decision |
|---|---|
| Scope at launch | Read-only. It answers; it never writes. Actions (log a meal, swap an exercise) are v2, behind confirmation cards. |
| Access | Premium only, checked on the server. |
| Model | Gemini 3.8 Flash on Vertex AI, through Genkit's Google GenAI plugin, as the existing callables use (2.5 Flash retired on 20 Oct 2026). |
| Region | `europe-west4` for the function; the Vertex endpoint is the `eu` multi-region, since current Gemini models aren't served from single regions. Firestore is `eur3`, so nothing leaves the EU. |
| Data access | Server-side tools. The function reads Firestore with the Admin SDK for the caller's uid; no round trips through the app. |
| Derived figures | Ported to the server (expenditure, weight trend, PRs and e1RM, muscle volume). See "Keeping the maths in step". |
| Premium check | RevenueCat REST API v2 (`GET /v2/projects/{project_id}/customers/{uid}/active_entitlements`), any active entitlement, cached briefly. The key is a V2 secret key with only *Customer information: read* permission, held in the `REVENUECAT_SECRET_KEY` Functions secret; a V1 key would have full write access to the account. The dev project skips the check, as dev builds do. |
| History | Saved under `users/{uid}/coach_chats`, deletable per chat, removed by `onUserDeleted`. |
| Limit | 50 messages per user per day, counted in Firestore by the function, plus a burst limit. |
| Entry points | A coach button on Today's toolbar, and "Ask about this" on the weight trend, exercise history and check-in. No new tab. |
| Generative UI | Since 19 Oct 2026, the Flutter app can ask for cards under an answer (charts, target bars, stats, buttons that open screens, follow-up questions). The model picks them; the server fills and lays them out. See [Generative UI (v1)](#generative-ui-v1). |

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

## Generative UI (v1)

Owner decisions, 19 Oct 2026. Blocks may show and navigate, never write. Saved chats keep a dated
snapshot. Flutter only: Swift and old builds get the text and ignore blocks. The client renders
them with its own renderer on the **A2UI v0.9** message format (not the genui package). The
**model picks blocks; the server lays them out.** Code: `functions/coach-blocks.js`.

The hard rule holds: **every number about the user comes from a tool.** The model never writes a
value into a block. The server fills every value from the same tool code, through a per-request
cache keyed by tool and arguments (`callCoachTool`), so a block and the model read the same result.

### Request

`coachChat` takes `ui: 1`, the catalog version the client renders. Absent, or any other value, is
the text-only coach exactly as before: no `show_block` tool, no guidance in the prompt, no block
chunks, nothing stored.

### The model's tool

`show_block(args)`, offered only when `ui` is 1, one call per block. The server checks the arguments
strictly (`parseBlockArgs`) and tells the model `{ shown: true, shows: <fallback> }` or
`{ shown: false, reason }`; a dropped block never ends the reply. At most 4 blocks a reply; calls
are handled one at a time, so the cap holds when several arrive together.

- `trend_chart` `{ metric: "weight" | "exercise_e1rm" | "expenditure" | "steps", exerciseId? (required for exercise_e1rm), rangeDays: 7..365 }`
- `target_bars` `{ day: "today" | "YYYY-MM-DD" }`, within the last 90 days.
- `stat_row` `{ stats: [StatKey…] (1..3) }`. StatKey is one of `weight_trend`, `weight_rate_per_week`,
  `goal_weight`, `expenditure`, `calorie_target`, `protein_target`, `today_calories`,
  `today_protein`, `steps_average`, `exercise_e1rm:<exerciseId>`.
- `actions` `{ actions: [Action…] (1..3) }`. Action: `{ kind: "log_weight" | "log_meal" | "start_workout" | "open_exercise" | "open_metric" | "open_check_in" | "open_diet_plan", exerciseId? (open_exercise only), metric?: "weight" | "expenditure" | "steps" (open_metric only) }`.
- `follow_ups` `{ questions: [string ≤ 80 chars, no digits] (1..3) }`: suggested prompts, not facts. A
  tap sends the text as the user's next message.

A block with nothing to show (no weigh-ins in range, an exercise the user never logged) is dropped
with the reason. Where each value comes from:

| Block | Tool call |
|---|---|
| `trend_chart` weight | `get_body_metrics({ days: rangeDays })`: weigh-ins and the app's trend (its latest 60 weigh-ins) |
| `trend_chart` exercise_e1rm | `get_exercise_progress({ exercise: exerciseId, weeks: ⌈rangeDays / 7⌉ })`, sessions of exactly that id within the range |
| `trend_chart` expenditure, steps | `get_expenditure` / `get_steps` with `{ days: rangeDays }` (both stop at 180) |
| `target_bars` | `get_nutrition({ days })` reaching back to that day: totals and that day's targets |
| `stat_row` | the defaults of `get_body_metrics`, `get_expenditure`, `get_profile_and_targets`, `get_steps`; `get_nutrition({ days: 1 })` for today; `get_exercise_progress` (app's latest e1RM) |
| `actions` | `get_exercise_progress({ weeks: 104 })` names an `open_exercise` |

### Stream chunk for a block

Every chunk keeps a `text` key (Swift and earlier Dart throw without it):

```json
{ "text": "", "block": {
    "surfaceId": "<messageId>-<n>", "kind": "trend_chart", "asOf": "YYYY-MM-DD",
    "fallback": "Weight trend, 2026-09-08 to 2026-10-05: 81.7 → 79.8 kg.",
    "messages": [ <A2UI v0.9 messages, in order> ] } }
```

`n` counts from 0 in the order blocks were shown. Text chunks are unchanged. Blocks may arrive
before, between or after text chunks; v1 clients render all of the message's text first, then its
blocks in arrival order. `fallback` is plain text the server writes from the same data.

### A2UI v0.9 messages (one surface per block)

Each is `{ "version": "v0.9", <one key> }`:

1. `createSurface { surfaceId, catalogId: "compound.coach.v1" }`
2. `updateComponents { surfaceId, components: [ { id: "root", component: <Name>, …props } ] }`.
   Every data prop is a binding `{ "path": "/…" }`; the only literals are `id`, `component` and
   `TrendChart`'s `metric` enum. No user value is ever in a component.
3. `updateDataModel { surfaceId, path: "/", value: { … } }`: raw numbers plus unit kinds, in the
   user's units. The client formats with `AppFormat` and localises labels from the enums.

Catalog `compound.coach.v1`:

| Component | Props | Data at the bound paths |
|---|---|---|
| `TrendChart` | `metric`, `points: {path:"/points"}`, `trend: {path:"/trend"}` (weight only), `unit: {path:"/unit"}`, `exerciseName: {path:"/exerciseName"}` (e1RM only) | `points`/`trend`: `[{x:"YYYY-MM-DD", y:number}]`; `unit`: `"kg"\|"lb"\|"kcal"\|"steps"` |
| `TargetBars` | `rows: {path:"/rows"}`, `day: {path:"/day"}` | `rows`: `[{nutrient:"calories"\|"protein"\|"carbs"\|"fat", value:number\|null, target:number\|null, unit:"kcal"\|"g"}]` |
| `StatRow` | `stats: {path:"/stats"}` | `[{key:StatKey, value:number\|null, unit:"kg"\|"lb"\|"kg_per_week"\|"lb_per_week"\|"kcal"\|"g"\|"steps", exerciseName?:string}]` |
| `Actions` | `actions: {path:"/actions"}` | `[{kind, exerciseId?, exerciseName?, metric?}]`; labels come from the kind, client-side |
| `FollowUps` | `questions: {path:"/questions"}` | `[string]` |

A value the tools don't have is `null`; the client shows the usual placeholder. An unknown
component, an invalid message or an empty `messages` list renders the block's `fallback` instead.

### Persistence and history

The assistant message in `users/{uid}/coach_chats/{id}` gains an optional `blocks` array: the
`block` objects above, in order, with `as_of` in snake_case like the other fields (`surfaceId`,
`kind`, `as_of`, `fallback`, `messages`), written in the same transaction as the exchange. The key
is absent when a reply has no blocks. Old chats replay offline from the snapshot, labelled "as of
<date>". If a chat would outgrow its document, the oldest blocks' `messages` are emptied first, so
they show their fallback (`fitStoredBlocks`). The contract fixture is
`contracts/firestore/coach_chat/with-blocks.json`; Swift ignores the field, Dart keeps it
(`CoachBlock`).

The model's history for later turns is the reply's text plus one line per block:
`[Shown: <fallback>]`.

### Privacy and limits

Blocks read only through the ten tools, so nothing new is reachable: no Strava, photos or other
people (`coach-blocks.test.js` holds this with a guarded data source and a source check). At most 4
blocks a reply. `follow_ups` text is length-limited and carries no figures.

`node scripts/coach-eval.js --ui` checks the block chosen for four questions and that every figure
in each block equals the tools'.

## Evaluation

A set of questions against fixture accounts (cutting, bulking, stalled, new user, no plan), each
with the figures a correct answer must quote. It runs before release and on prompt or model
changes.
