# Compound: Mixpanel business context

Source for the business context stored in the Mixpanel **Compound** project (id `4069561`, EU
data residency). Paste the block below into Mixpanel, or set it with the Mixpanel MCP's
`Update-Business-Context` (`level: project`). The project is in the EU, so use the EU MCP
server (`mcp-eu.mixpanel.com`). Edit this file first and keep the two in step.

---

## Product

Compound is an iPhone and iPad app (iOS 26+) for strength training and nutrition. The
**Stamina** project in the same org is a separate app and has nothing to do with Compound.

The app has five tabs:
- **Today**: today's workout card, streak, nutrition summary, weekly check-in.
- **Training**: workouts, exercises, mesocycles (a program of day plans run for N weeks) and macrocycles (ordered mesocycles).
- **Nutrition**: meal log, food and recipe library, AI meal analysis, nutrition targets.
- **Progress**: the analytics screens, body metrics, progress photos and habits. The code calls this area "Analytics".
- **Social**: feed, follows, likes, comments, challenges, nudges.

Premium is sold through RevenueCat. Users can sign in with Apple, with Google, or anonymously.

## Event naming

Every event name has the form `{Source}_{Action}[_{Outcome}]`.

- **Screens** log `{ViewName}_Appear` and `{ViewName}_Disappear`, for example
  `AddMealView_Appear`. Only full screens log these; components embedded in a screen do not.
  `_Disappear` also fires when another screen is pushed on top. **Count screen views with
  `_Appear`**, never with `_Disappear`.
- **Operations** log `{ViewName}_{Action}_Start`, `_Success` and `_Fail`, for example
  `AddMealView_SaveMeal_Start`. Success rate is `_Success` divided by `_Start`. Reads and loads
  usually log only `_Fail`.
- **Taps** with no outcome are `{ViewName}_{Action}` or `…_Pressed`.
- **Managers and packages** use their own prefixes:
  - `Auth_*`: sign in, sign out, delete account.
  - `Purchasing_*`: products, purchase, restore, entitlements.
  - `ProgressMan_*`, `StreakMan_*`, `XPMan_*`: gamification.
  - `HKWorkoutMan_*`: the HealthKit workout session and rest timer.
  - `ABMan_*`: A/B tests.
  - `Onboarding_*`: onboarding steps.
- **Families share one event name** and are told apart by a property:
  - `LogMeasurementView_*` and `BodyMeasurementDetailView_*`: `measurement`, one of 18 body circumferences.
  - `NutritionMetricDetailView_*`: `metric`.
  - `BodyRatioView_*`: `ratio`.
  - `MuscleGroupDetailView_*`: `muscle`.
  - `ExerciseDetailView_*`: `exercise_template_id`.
  - `NutritionLibraryPickerView_Tab_Selected`: `tab`, the food logger mode: `library`, `search`, `describe`, `aiScanner` (photo), `barcode` or `quickAdd`.

**Older names.** A few events predate this scheme, for example `BarcodeScanner_ParseLabel`,
`MealDescribe_Error` and `NutritionTargetChart_CreatePlan_Pressed`. They were kept so that
existing reports keep working.

## Properties

- `_Fail` events carry `error_description`, `error_domain` and `error_code`. Some also carry
  `error`, a plain message, instead.
- Severity (info, analytic, warning, severe) is **not** sent to Mixpanel. Find failures by the
  `_Fail` suffix.
- User profile properties:
  - From sign-in: `$name`, `$email`, and the `user_*` fields of the account
    (`user_is_anonymous`, `user_auth_providers`, `user_creation_date`, …).
  - The device and app (`utility_*`).
  - `push_is_authorised`.
  - Active A/B test arms: `test_20241205_PaywallTest` and `test_20251205_notifications_test`.
- The distinct id is the Firebase Auth uid. An anonymous user who later links Apple or Google
  keeps the same uid.

## Key flows

- **Onboarding funnel.** The step folders run Welcome (0), Auth (2), Subscription (3), account
  setup (4: name and photo, gender, date of birth, height, weight, exercise frequency, activity,
  expenditure, health disclaimer), goal setup (5–6: objective, target weight, weight rate,
  summary), diet program (8: preferred diet, calorie floor, distribution, protein, plan), and
  Completed (9). Build the funnel from each step's `…View_Appear`; leaving a step logs
  `…_Navigate`.
  - The goal and diet steps can also be opened from Settings after onboarding. Those
    `_Appear` events have no property marking them as Settings, so limit an onboarding funnel to
    users created in the window.
- **Workout.**
  - The flow runs from `WorkoutTrackerView_Appear` (a workout started from Today, Training or a
    template) to finishing the workout, then to `WorkoutSessionDetailView_Appear`.
  - Templates and mesocycles drive which workout is scheduled for today.
- **Meal logging.**
  - The flow runs from `AddMealView_Appear` to `NutritionLibraryPickerView_Appear` (the food
    logger), to tab choices, to `AddMealView_SaveMeal_Success`.
  - AI analysis appears as the Describe and Photo tabs, and barcode lookup as the Barcode tab.
- **Paywall.**
  - `PaywallView_*` and the onboarding `SubscriptionView_*` cover the paywall screens.
  - `Purchasing_Purchase_*` covers the purchase itself.

## Caveats

- **Development builds send to this project too.** Dev and prod builds use the same token, so
  testers' and the developer's activity is mixed in, and no property marks the build. Exclude
  internal users by distinct id, or exclude by app version during a TestFlight period.
- **Coverage is uneven before October 2026.**
  - Screen and operation events were filled in across the app in October 2026. Before that,
    about 40% of screens logged no `_Appear`, onboarding logged only `_Navigate`, and much of
    the workout flow logged nothing.
  - Do not compare usage across that date without checking that the event existed earlier.
- **Data residency.** The project stores data in the EU, and the app sends to
  `api-eu.mixpanel.com`.
