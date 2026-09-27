# WP-12 · Migrate Profile, settings and paywalls

**Wave 3. Size: large (about 45 views).** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Profile/**`
- `Core/Paywalls/**`
- `Components/Buttons/SignInWith*`
- `Components/Modals/`, except `CustomModalView`, which WP-07 owns

## Specific issues

- **Settings rows are built four ways:**
  - hand-rolled `Label` + `.frame` + `.tappableBackground` + `.anyButton`, about 22 in
    `ProfileView.swift:96-125`
  - `CustomLabelButtonView`
  - raw `HStack` with a chevron (`AccountView.swift:143-156`)
  - `NavigationLink`, which is never used

  All become `ListRowButton`, `ListRowToggle`, or an inline `Picker` for enum settings. Follow
  `UnitsView.swift:29-39`, the reference pattern.
- **Title modes.** Profile uses `.inline` and About uses `.inlineLarge`. Make them consistent.
- **Close placement** varies between leading and trailing (`ProfileView.swift:277`,
  `AboutView.swift:39`, `LicencesView.swift:33`, `EditBandView.swift:76`). Use `role: .close` in
  `.cancellationAction`.
- **`GymProfileView.swift:~476`** replaces the system back button with its own `chevron.left`.
  Remove it, unless it guards unsaved changes; in that case use a confirm dialog and say so.
  - The file also repeats `.cornerRadius(8)` 11 times.
- **Add sheets** (`AddBandView`, `AddFreeWeightView`) use icon ✓/✕; others use "Done", "Save"
  and "Cancel" text. Use the contract toolbar roles.
  - Detent fractions 0.2–0.53 become presets.
- **Band colour swatches** in `AddBandView` have no accessible names. Add names.
- **Log Out** (`AccountView.swift:~191-199`) is a plain `Text.anyButton`. Delete Account is
  destructive. Make Log Out a `ListRowButton` without a chevron, and Delete Account a
  `Button(role: .destructive)`.
- **Symbol collisions** in `ProfileView.swift:150,214,243,255` (`map`, `book`). Take the symbols
  from `Symbol`.
  - The avatar placeholder is `person.circle` here and `person.crop.circle` in onboarding. Pick one.
- **Paywalls.**
  - `CustomPaywallView` cards use a one-off shadow and stroke. Use `.cardSurface` with a selected
    state (a stroke in `accentColor`, and `.isSelected`).
  - `.badgeButton` becomes `Chip`.
  - `PaywallView.swift:30` uses a hand-rolled `.glassProminent`. Use `CallToActionButton`.
  - The RevenueCat and StoreKit variants stay system UI.
- **Sign-in buttons.** Google is 50pt tall with radius 25 inside a 56pt frame
  (`SignInWithGoogleButtonView.swift:55-63`). Apple is 56pt with radius 28. Match them.
- **Deprecated `.foregroundColor`.** It is used about 27 times, most of them in
  `Subviews/TrainingSettings/Exercises/ExerciseTemplateDetail/ExerciseTemplateDetailView.swift:70-279`.
  That file is yours, even though its name sounds like Training.
