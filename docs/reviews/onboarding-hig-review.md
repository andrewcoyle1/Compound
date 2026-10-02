# Onboarding, permissions and sign-in: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`. Pages read:
`designing-for-ios`, `onboarding`, `privacy`, `healthkit`, `managing-notifications`,
`sign-in-with-apple`, `managing-accounts`, plus `layout` and `materials` for finding 9.

**Scope.** Code read: `Core/Onboarding/` steps 0, 1, 2, 5, 9, permission steps 4/10 and 4/11,
`Components/Buttons/SignInWith*ButtonView.swift`, `CallToActionButton.swift`,
`Managers/HealthKitManager/Service/HealthKitService.swift`, and the purpose strings in
`project.pbxproj`. **Not reviewed:** the paywall (step 3), the data-entry steps (4/1–4/9, 6, 8).

**Not checked.** This is a code review. Nothing was run, so Dark Mode, the largest text sizes,
VoiceOver, iPad and Mac Catalyst are all unverified.

Paths are relative to `DialedIn/`. Findings are most serious first.

## Resolution (2026-09-28, branch `feature/hig`)

The review was first read against `feature/overnight-2`, which turned out to be 163 commits
behind `feature/ui-framework`. Every finding was re-checked on `feature/hig`, cut from
`feature/ui-framework`. Line numbers below are from the older branch.

| # | Finding | Status |
|---|---|---|
| 1 | Health request wider than the screen says | **Fixed.** `HealthDataScope` (`workouts`, `steps`, `bodyMeasurements`) replaces the single request. Types nothing read are no longer requested: all dietary types, activity summary, basal energy, BMI, lean mass, height, waist. Both purpose strings rewritten. |
| 2 | Two custom prompts before the notification alert | **Fixed** by removing the step. |
| 3 | Health button titled "Allow…", plus a skip | **Fixed** by removing the step. |
| 4 | Permissions asked during onboarding | **Fixed.** Steps 4/10 and 4/11 are deleted. Expenditure goes straight to the disclaimer. Weight access is requested when weight is first logged or its history opened; workouts and steps already asked in context. `OnboardingStep.notifications` and `.healthData` stay as cases because stored profiles can name them, and both resume at the disclaimer. |
| 5 | Sign-in with no stated reason | **Partly fixed.** The sign-in screen now says what the account is for. Sign-in still comes before any use of the app; delaying it is a product change. |
| 6 | Sign in with Apple under a tap overlay | **Already fixed** on `feature/ui-framework` (the wrapper has an accessibility label). Still worth one VoiceOver pass. |
| 7 | "HealthKit" in user-facing text | **Fixed.** Both strings say "Apple Health"; Spanish updated. |
| 8 | Fixed type sizes | **Already fixed** on `feature/ui-framework`. |
| 9 | Opaque material behind bottom controls | **Already fixed** for the disclaimer. `AuthView` still puts `.regularMaterial` behind its title. |
| 10 | Onboarding length | Two screens shorter. Otherwise unchanged; product call. |

Smaller items: the duplicate `navigationBarTitleDisplayMode` went with the deleted screen.
`NSUserTrackingUsageDescription` and `NSCalendarsUsageDescription` are **not** a finding:
`docs/AppPrivacy.md` records that they stay on purpose because `SwiftfulUtilities` links the
frameworks.

Notifications are now requested in two places: when the first rest timer schedules its
"Rest Complete" alert (`PushManager.schedulePushNotification`), and from the in-app notifications
screen. Meal reminders and the re-engagement week are scheduled without a prompt, as before, so
they stay silent until the person has allowed notifications one of those two ways.

## Findings

### 1. The Health screen says "weight"; the request covers about sixty types
Severity: hurts usability (trust), App Review exposure
Where: `Core/Onboarding/4 - CompleteAccountSetup/11 - HealthData/HealthDataView.swift:82`,
`Managers/HealthKitManager/Service/HealthKitService.swift:15`, `:72`, `:141`
Guideline: "Request access only to data that you actually need… making your permission requests
as specific as possible." and "Be transparent about how your app collects and uses people's
data." — https://developer.apple.com/design/human-interface-guidelines/privacy
What happens: the screen says Compound "needs permission to read and write your weight data".
The single `requestAuthorization` call then asks to read workouts, activity summary, active and
basal energy, heart rate, steps, 40+ dietary types and six body measurements, and to write
workouts, nutrition and body measurements. The purpose strings disagree too:
`NSHealthUpdateUsageDescription` mentions only "workouts and active energy", and
`NSHealthShareUsageDescription` omits workouts, heart rate and steps.
Fix: split the request by feature. Ask for `bodyMass` where weight is logged, workout types when
a workout starts (`WorkoutTrackerInteractor` already has the call), steps on the Steps screen
(same), nutrition when food logging first syncs. Rewrite both purpose strings to name every
category, and start them with the app name rather than "This app".

### 2. Notifications: two custom prompts before the system alert, each with a way out
Severity: hurts usability, App Review exposure
Where: `…/10 - NotificationsPermissions/NotificationsPermissionsView.swift:39`, `:46`;
`NotificationsPermissionsRouter.swift:19-39`; `NotificationsPermissionsPresenter.swift:33`
Guideline: "Include only one button and make it clear that it opens the system alert… Use a term
like 'Continue' or 'Next'" and "Don't include additional actions… like offering an option to
close or cancel." — https://developer.apple.com/design/human-interface-guidelines/privacy#Pre-alert-screens-windows-or-views
What happens: screen ("Enable notifications" / "Skip for now") → custom modal "Enable Push
Notifications?" ("Enable" / "Cancel", also dismissed by tapping outside) → system alert.
Caveat: the page lists "camera, microphone, location, contact, calendar, and tracking" as
examples and does not name notifications, so applying it here is a reading, not a quote.
Fix: delete the custom modal and call `requestPushAuthorisation()` straight from the screen's
button; title that button "Continue"; remove "Skip for now" (the system alert's Don't Allow is
the skip). `buttonSection` at `NotificationsPermissionsView.swift:106` is unused — delete it.

### 3. Health screen: button titled "Allow…", plus a skip
Severity: hurts usability, App Review exposure
Where: `…/11 - HealthData/HealthDataView.swift:41`, `:48`
Guideline: "Another type of manipulation is using a term like 'Allow' to title the custom
screen's button." — privacy page, same section. Also "Avoid adding custom screens that replicate
the standard permission screen's behavior or content." —
https://developer.apple.com/design/human-interface-guidelines/healthkit
Fix: title the button "Continue" and remove "Skip for now". Or drop the screen (finding 4).

### 4. Both permissions are asked during onboarding, not when needed
Severity: hurts usability
Where: onboarding steps 4/10 and 4/11
Guideline: "Ideally, wait to request permission until people actually use an app feature that
requires access." — privacy page. "It makes sense to request access to weight information when
people log their weight, for example, but not immediately after your app launches." — healthkit
page.
Fix: in-context requests already exist (`WorkoutTrackerInteractor`, `StepsInteractor`,
`Core/Notifications/NotificationsPresenter.swift:132`). Removing steps 4/10 and 4/11 resolves
findings 2, 3 and 4 together and shortens onboarding by two screens. This is a product decision.

### 5. Sign-in comes before any use of the app, with no stated reason
Severity: hurts usability
Where: `Core/Onboarding/2 - AuthView/AuthView.swift` (whole screen); flow Welcome → Intro → Auth
Guideline: "Delay sign-in as long as possible." and "Explain the benefits of creating an account
and how to sign up… Display this message in your sign-in view." —
https://developer.apple.com/design/human-interface-guidelines/managing-accounts
Fix (smallest): one or two lines on `AuthView` saying what the account is for (sync across
devices, backup). Delaying sign-in properly is a larger product change.

### 6. Sign in with Apple is a disabled system button under a tap overlay
Severity: possibly blocks VoiceOver users — **unverified, my judgment**
Where: `Components/Buttons/SignInWithAppleButtonView.swift:77`, `:80`
Guideline: "Every interactive element has an accessibility label" (accessibility baseline).
What happens: the real `ASAuthorizationAppleIDButton` is `.disabled(true)` and an `anyButton`
wrapper takes the tap. A disabled control can be announced as dimmed or skipped, and the wrapper
sets no label or button trait.
Fix: test with VoiceOver first. If it reads wrongly, add
`.accessibilityElement(children: .ignore)`, `.accessibilityLabel(…)` and
`.accessibilityAddTraits(.isButton)` to the wrapper.

### 7. "HealthKit" appears in user-facing text
Severity: polish
Where: `Core/Onboarding/3 - Subscription/SubscriptionView.swift:69` ("HealthKit sync"),
`Managers/BodyMeasurements/Models/WeightSource.swift:19` ("HealthKit")
Guideline: "Don't use the term HealthKit… use the term the Apple Health app." — healthkit page
Fix: "Apple Health sync" and "Apple Health".

### 8. Fixed type sizes on the first three screens
Severity: polish (already covered by the Dynamic Type rule and WP-13)
Where: `2 - AuthView/AuthView.swift:37` (48), `0 - WelcomeView/WelcomeView.swift:73` (40),
`9 - StravaConnect/StravaConnectView.swift:19` (72);
`Components/Buttons/SignInWithGoogleButtonView.swift:50`, `:55` (`.title3` text in a fixed
50 pt height)
Guideline: text scales; layouts survive the largest sizes —
https://developer.apple.com/design/human-interface-guidelines/accessibility
Fix: text-style tokens and `@ScaledMetric` per `CONTRACT.md`; `minHeight` instead of `height`.

### 9. Opaque material behind bottom controls
Severity: polish (already in `docs/ui-audit.md`)
Where: `5 - HealthDisclaimer/HealthDisclaimerView.swift:65` (`.background(.bar)`),
`2 - AuthView/AuthView.swift:38-40`
Guideline: "Instead of applying a solid or semi-opaque background color beneath controls, use a
scroll edge effect" — https://developer.apple.com/design/human-interface-guidelines/layout
Fix: remove the backgrounds and let the scroll edge effect separate controls from content.

### 10. Onboarding length
Severity: my judgment
Where: `Core/Onboarding/` — about 25 prerequisite screens; the back button is hidden on five
Guideline: "design a brief, enjoyable experience" and "fast, fun, and optional" —
https://developer.apple.com/design/human-interface-guidelines/onboarding
Note only. The profile data drives the calorie and programme maths, so this is a product call.

## Smaller items

- `HealthDataView.swift:22` and `:29` set `navigationBarTitleDisplayMode` twice (`.inline`, then
  `.large`).
- `NSUserTrackingUsageDescription` ("personalised ads") and `NSCalendarsUsageDescription` are
  declared, but no `ATTrackingManager` or `EKEventStore` call exists under `DialedIn/`. Packages
  were not searched. If neither is used, remove the strings.

## Done well — keep through the refactor

- Sign in with Apple is the first button, uses the system-provided `ASAuthorizationAppleIDButton`,
  and switches black/white with the appearance. At 56 pt it is no smaller than the Google button
  (50 pt) and above the 140×30 pt minimum.
- The Health screen's own copy says "Apple Health", not HealthKit.
- An in-app notification settings screen (`Core/Notifications/`) and an account-deletion entry
  point (`Core/Profile/Subviews/Account/`) both exist. Their flows were not reviewed.
- The permission screens say how to change the choice later in Settings.
