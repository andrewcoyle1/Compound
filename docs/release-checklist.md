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
- [ ] Calorie floors: 1,200 kcal standard; 800 kcal offered only in settings.
- [ ] The midpoint coefficient used for "Prefer not to say" in the calorie estimate.
- [ ] For "Prefer not to say", the Harris-Benedict estimate uses the average of its two equations.
- [ ] The weekly-rate bands: warning from 80% of the person's maximum, "Conservative" at 50% or less.
- [ ] Spanish for the two health consent texts (marked `needs_review` in the string catalog).
- [ ] Whether health consent may be one "Agree and Continue" button or needs separate toggles.

## Check once

- [ ] **The Production build's optimisation level.** It is `-Osize` to avoid a compiler crash in
      Xcode 27.0 (see `CLAUDE.md`, Code Health Baseline). Try the default `-O` again with each
      new Xcode, or build releases with Xcode 26.6.

- [ ] How long Google's Vertex AI keeps the photos and text sent for analysis, so the in-app
      disclosure stays true.
- [ ] The Time Sensitive Notifications capability is enabled for the app ID.
- [ ] A capture of the screenshot deck on iOS 26.5, which renders differently from iOS 27.
- [ ] Large text sizes, VoiceOver and iPad, on a device.

## Design and product work not yet started

- [ ] App icon rebuilt in Icon Composer from a plain background and a vector "C".
- [ ] Muscle artwork for the muscle picker.
- [ ] A rest-complete sound file (a system sound stands in).
- [ ] The Mac version: fix the Catalyst build, menus, and Apple Health on the Mac.
- [ ] Public food database contribution (the Food Packaging step and its setting are hidden).
- [ ] The features behind the hidden Profile rows: Knowledge Base, Roadmap, App Icon, Tutorials,
      Exercise Assessment, Premove.
- [ ] The free trial itself.
