# Release checklist

Things that must be true before a build goes to the App Store. Each is marked in the code with
`// TODO:` where there is a place to mark. Add to this list; do not rely on memory.

## Blocks release

- [ ] **Legal documents published.** Terms of Service, Privacy Policy, Health Disclaimer and
      Consumer Health Privacy Notice, hosted on the owner's website. Replace the four
      placeholder addresses in `DialedIn/Utilities/Constants.swift` (all point at apple.com).
- [ ] **Sign in with Apple token revoked on account deletion.** Fix the
      `SwiftfulAuthenticatingFirebase` fork first (a failed revocation must not leave a
      half-deleted account), then pass `revokeToken:` from `CoreInteractor`. See
      `docs/reviews/hig-handoffs.md`.
- [ ] **App Review rules for the free trial read** before the trial is built. The plan is an
      app-managed trial with no payment sign-up; check how Apple allows time-limited free access
      to be offered. The trial's start date must be stored on the server.

## Confirm with someone qualified

- [ ] Maximum weekly rate of weight change: 1% of body weight.
- [ ] Lowest selectable target weight: BMI 18.5 for the person's height.
- [ ] Calorie floors: 1,200 kcal (women), 1,500 (men), 1,350 (not stated); the 800 kcal option
      was removed. A goal's deficit is capped at 25% of expenditure.
- [ ] The midpoint coefficient used for "Prefer not to say" in the calorie estimate.
- [ ] For "Prefer not to say", the Harris-Benedict estimate uses the average of its two equations.
- [ ] The weekly-rate bands, as % of body weight a week: losing 0.25–1%, default 0.5% (BMI < 25)
      or 0.75%, warning above 0.75% for BMI < 25; gaining 0.1–1%, default 0.25%, warning above 0.5%.
- [ ] Spanish for the two health consent texts (marked `needs_review` in the string catalog).
- [ ] Whether health consent may be one "Agree and Continue" button or needs separate toggles.

## Check once

- [ ] **The Production build carries no coverage instrumentation.** Run
      `xcodebuild -showBuildSettings -project DialedIn.xcodeproj -scheme 'DialedIn - Production' | grep CLANG_COVERAGE_MAPPING`
      and expect no `YES`. Xcode 27 turns coverage on through the scheme's auto-created test plan,
      which both slows the app and crashes the compiler at `-O` (see `CLAUDE.md`, Code Health
      Baseline).

- [ ] How long Google's Vertex AI keeps the photos and text sent for analysis, so the in-app
      disclosure stays true.
- [ ] **Time Sensitive Notifications.** Enable the capability for the App ID, then add
      `com.apple.developer.usernotifications.time-sensitive` (true) to `DialedIn.entitlements` and
      `DialedIn-Debug.entitlements`. It is left out until then, because a device build will not
      sign with an entitlement the App ID lacks. Without it "Rest complete" is delivered as an
      ordinary notification.
- [ ] **Deploy the Cloud Functions** (`firebase deploy --only functions`) together with the app
      release that expects them: localized pushes, interruption levels, the real badge count.
- [ ] Run `npm run test:triggers` in `functions/` on a machine with Java 21 or later.
- [ ] A capture of the screenshot deck on iOS 26.5, which renders differently from iOS 27.
- [ ] Large text sizes, VoiceOver and iPad, on a device.

## Design and product work not yet started

`// Pending:` comments in the code mark where each of these lands. They are not `TODO`s because
`swiftlint --strict` fails CI on those.

- [ ] App icon rebuilt in Icon Composer from a plain background and a vector "C".
- [ ] Muscle artwork for the muscle picker.
- [ ] A rest-complete sound file (a system sound stands in).
- [ ] The Mac version: fix the Catalyst build, menus, and Apple Health on the Mac.
- [ ] Public food database contribution (the Food Packaging step and its setting are hidden).
- [ ] The features behind the hidden Profile rows: Knowledge Base, Roadmap, App Icon, Tutorials,
      Exercise Assessment, Premove.
- [ ] The free trial itself.
- [ ] Editing a finished workout's sets and exercises (decision 11a, second step).
