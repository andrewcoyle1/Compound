# Tab layout and user workflows: UX audit (2026-09-30)

**What this is.** An information-architecture pass over the five tabs: what each tab holds, where
each everyday job starts, and what is duplicated, buried or unreachable. The HIG reviews in this
folder cover per-screen compliance; this one covers *where things live*.

**Method.** Code read only: `Core/TabBar/`, the five tab roots (`DashboardView`, `TrainingView`,
`NutritionView`, `AnalyticsView`, `SearchView`), their presenters and routers, `ProfileView`,
`MealHourHeader`, `ActiveTrainingProgram`, `NutritionOverview`, `ShortcutSettings`, and every
caller of the routes named below (grepped). Live HIG `tab-bars` read with the `apple-hig` skill.
**Not run in the simulator**: no screenshots, no appearance or text-size checks. Tap counts are
from the code paths, not measured.

## The shell today

| Tab | Leads with | Toolbar | "More" rows at the bottom |
|---|---|---|---|
| **Dashboard** | Carousel: Today's Workout (only if a program schedules today), Streak, Nutrition; then weekly summary, Weekly Review card, invite card, circle strip, leaderboard, challenges, workout feed | Bell (badged), Profile | — |
| **Training** | Calendar bar; active program (collapsible microcycle list) or "Choose Program" | Calendar, **+** menu (New Program/Workout/Exercise), Profile | Programs, Workout Library, Start Empty Workout, Workout History |
| **Nutrition** | Calendar bar, macro rings; hour-by-hour timeline | Calendar, **⋯** (Copy/Clear Day, two toggles), Profile | Nutrition Overview, Customize Food Log |
| **Analytics** | Nutrition target chart; seven customisable card sections | Profile | Hidden sections, Weekly Review, Customize Analytics |
| **Search** (`role: .search`) | Empty: shortcut chips (Start Workout, Log Meal, Log Weight, Log Measurement), recents, Enter Invite Code. Typed: people, exercises, workouts, recipes, foods | Profile | — |

Profile (full-screen cover from the avatar on every tab) holds settings **and** two libraries:
Exercises and Gym Profiles.

## Everyday jobs, and where they start

| Job | Routes in | Verdict |
|---|---|---|
| Start today's program workout | Dashboard Today card; Training program row | OK, but Training does not mark which row is today (F5) |
| Start an unplanned workout | Training → scroll to **More** → Start Empty Workout; Search chip | Buried (F4) |
| Log a meal | Dashboard Nutrition card; Search chip; Nutrition hour-header **+** (setting-dependent); draft-meal accessory | **The Nutrition tab has no dependable entry** (F1) |
| Log weight | Search chip; Analytics → Scale Weight / Weight Trend / Goal Progress / Weigh-In detail → log | Only in a search tab or four levels of Analytics (F2) |
| Log a measurement / progress photo | Search chip → Body Metrics; Analytics → Body Metrics | Same as weight (F2) |
| Weekly nutrition check-in | Nutrition → More → Nutrition Overview → card | **Nothing surfaces it** (F3) |
| Browse exercises | Profile → Exercises; Search (typed, or non-default chip) | In settings, not Training (F6) |
| Browse recipes | Search non-default chip only | Effectively hidden (F6) |
| Browse my foods | Only inside the Add Meal picker; `showFoodsView()` has no callers | Unreachable as a library (F6) |
| Workout history | Training → More → Workout History; Training calendar | OK |
| Weekly Review | Dashboard card (when due); Analytics → More | OK — two routes, one purpose |
| Notifications | Dashboard bell; Profile | OK |
| Find people / invite | Dashboard feed header + empty state; Search; Search → Enter Invite Code; Profile → Invite | OK |

## Findings

Ranked by how often the job happens times how hard it is to find.

### F1. The Nutrition tab has no primary "Log Meal" control — blocks people in one configuration
*Hurts usability; blocks people when Hide Empty Hours is on.*

- `NutritionView.swift:33` — the only add controls are per-hour **+** buttons in
  `MealHourHeaderView.swift:34`, shown only when `showAddFoodsButton` is on. With it off, adding is
  a **long-press on the time chip** (`MealHourHeaderView.swift:26`), which nothing on screen hints at.
- `NutritionPresenter.swift:72` — with **Hide Empty Hours** on (a toggle one tap away in the ⋯ sheet)
  and nothing logged yet today, `timelineHours` is empty. The tab then shows the rings and the More
  section: no hours, no **+**, no empty state. The main job of the tab has no way in; the person
  must go to Dashboard or Search.
- The toolbar holds Calendar and ⋯ (Copy Day / Clear Day / display toggles) — the destructive and
  rare actions got the toolbar slot the frequent one should have.

**Fix.** Add a **+** (Log Meal) to the Nutrition toolbar, calling the existing
`MealHourHeaderPresenter.onAddMealPressed` logic (draft-meal dialog included) at the current time
on today, or noon on a past day. Keep the per-hour buttons as the time-specific shortcut. Give the
empty day a `ContentUnavailableView` ("Nothing Logged" + Log Meal). Consider moving the display
toggles out of ⋯ into Customize Food Log so ⋯ is just Copy/Clear Day.

### F2. Weight and body measurements have no home tab
*Hurts usability.* Weigh-ins are a daily habit (Analytics even tracks a Weigh-In streak), yet
logging one starts from either:
- the **Search** tab's chip (`ShortcutSettings.swift:72`) — nobody looks in Search to *record*
  something, and the chip disappears the moment the person types; or
- **Analytics → Scale Weight** (or three other metric screens) → log button.

**Fix, smallest first.** (a) Add a Weight card to the Dashboard carousel beside Nutrition, with a
Log button, reusing `showLogWeightView()`; or (b) add a **+** to Analytics' toolbar with Log
Weight / Log Measurement / Add Progress Photo. (a) matches how Nutrition is already handled.

### F3. The weekly check-in is invisible unless you go looking
*Hurts usability — the adaptive-nutrition loop depends on it.*
`NutritionOverviewView.swift:15` is the **only** place a due check-in appears
(`dueCheckInWeekStart` is read nowhere else). The route is Nutrition → scroll past the whole
timeline → More → Nutrition Overview. No badge, no Dashboard card, no notification.

**Fix.** When a check-in is due, show the same decision card at the top of the Nutrition tab
(and/or as a Dashboard card like `WeeklyReviewCard`). The presenter logic already exists.

### F4. The Training tab's actions sit under a "More" heading below the program
*Hurts usability.* `TrainingView.swift:82` — **Start Empty Workout** is the third row of a section
titled "More", below an expanded program that can be a dozen rows long. The Workout Library and
Programs are also there. Meanwhile the **+** menu at the top creates *templates*, not sessions, so
"+" on Training does not start a workout — a likely wrong guess for new users.

**Fix.** Put "Start Empty Workout" into the **+** menu as its first item (divider, then the three
New… items), or as a button under the program header. Rename the "More" section "Library" — it is
programs, workouts and history, not overflow. The same rename applies to Nutrition and Analytics.

### F5. Training's program list does not say which day is today
*Polish, frequent.* `MicrocycleItemRow.swift` has no today or next-up marker; the Dashboard's
Today card knows (`DashboardPresenter.todaysScheduledItem`) but Training, the tab named for it,
does not. Highlight the scheduled row (or show a "Today" chip) using that same computation.

### F6. The libraries are scattered, and two are unreachable
*Hurts usability.*

| Library | Lives in | Should live in |
|---|---|---|
| Programs, Workouts, History | Training → More | ✓ |
| **Exercises** | Profile → Training settings (`ProfileView.swift:136`) | Training → Library |
| **Gym Profiles** | Profile | Profile is fine (it is setup), but also offer it where a workout picks one |
| **Recipes** | Search chip, not in the defaults | Nutrition → Library |
| **Foods** | Only inside the Add Meal picker; `FoodsView.showFoodsView()` has **no callers** | Nutrition → Library |

A person who wants to edit a custom food or recipe has no route except starting a meal. Profile
is a settings sheet; libraries of content the person made belong under the tab they're used in.

**Fix.** Nutrition gets a "Library" section with Foods and Recipes (routes already exist:
`showFoodsView`, `showRecipesView`). Training's section gains Exercises. Remove Exercises from
Profile once Training has it.

### F7. The Search tab is doing an "Add" tab's job
*Hurts usability.* `DeepLink.swift` records that this tab was "Add" until recently, and it still
is: its empty state is a launcher for recording things (`defaultActions` are Start Workout, Log
Meal, Log Weight, Log Measurement — the comment calls them "what the other tabs leave furthest
away"). The HIG: *"Use a tab bar to support navigation, not to provide actions."* The shortcuts
are a patch over F1, F2 and F4. Once those are fixed in their own tabs, the chips become
redundant and Search can be search: recents, then suggestions (recent exercises, foods, people).

**Recommendation.** Fix F1/F2/F4 first; then shrink the default chips to none (the Shortcuts
setting can stay for people who want them) rather than removing the feature outright.

### F8. Dashboard: personal "today" competes with six social blocks
*Hurts usability for solo users.* After the carousel, the list is weekly summary → Weekly Review →
invite card → circle strip → leaderboard → challenges → feed (`DashboardView.swift:153–215`). For
someone with no circle or friends the screen is mostly prompts to invite and follow; for someone
with a busy circle, today's numbers are one swipe-row at the top.
- The Today card vanishes on rest days and without a program, so the carousel's first card
  changes identity day to day. Keep a slot: "Rest day" or "Start a workout".
- The tab is named "Dashboard" but reads as Home + Social. Either rename it "Home" (and keep
  both), or split Social into its own tab later if the social features grow — five tabs plus
  Search would still fit, but only if the Search tab stops being the logging launcher (F7).

### F9. Four different nutrition summaries, none of which is the source of truth
*Polish, confusing.* Today's nutrition appears as: the Dashboard Nutrition card, the Nutrition
tab rings, the **Analytics header** chart (`AnalyticsView.swift:86`, the only header card
Analytics has), Analytics → Nutrition section, and Nutrition → Nutrition Overview. Analytics'
lead card being nutrition makes a training-first person's Analytics tab open on food.

**Fix.** Let Nutrition Overview be the nutrition detail (reached from the Nutrition rings, not a
"More" row); make the Analytics header something cross-cutting (e.g. weekly Energy Balance or
Goal Progress), or drop the header and lead with Insights.

### F10. Duplicated settings rows
*Polish.* Each is reachable from its tab and again from Profile: Food Log settings, Customize
Analytics, Shortcuts, Notifications. That is fine as a pattern *if* it is applied consistently —
Workout Settings has no route from Training, and Gym Profiles none from anywhere in Training.
Pick the rule "each tab links its own settings; Profile lists them all" and fill the gaps.

### F11. iPad sidebar has no Profile or Settings item
*Polish, regular width only.* `.sidebarAdaptable` turns the tabs into a sidebar, but Profile is
still only the avatar in each tab's toolbar. A sidebar has room for a Profile/Settings item (or a
`TabSection` for the libraries in F6), which would also give Mac Catalyst a Settings target.
Not checked in the simulator.

## Done well — keep

- **Deep links** land on the right tab and open the right sheet; unknown links do nothing rather
  than guess (`TabBarPresenter.onOpenURL`).
- **Badge discipline**: the Dashboard badge counts only things needing an answer (comments,
  mentions, follow requests) — exactly the HIG's "reserve badges for critical information".
- **Tab restore** via `@SceneStorage`, and one bottom accessory with a clear priority (workout
  over draft meal).
- **Profile avatar in the same spot on every tab**, with a zoom transition.
- Four tabs + system Search is the right count; no overflow "More" tab.

## Suggested order

1. F1 (Nutrition **+** and empty state) — small, removes a dead end.
2. F4 + F5 (Start Empty Workout in **+**, today marker) — small.
3. F3 (surface the check-in) — small, presenter exists.
4. F6 (Library sections; wire `showFoodsView`) — small-medium, all routes exist.
5. F2 (Weight card) — medium.
6. F7, F9 (Search and Analytics header rethink) — product decisions, after 1–5.
7. F8, F10, F11 — decisions / polish.
