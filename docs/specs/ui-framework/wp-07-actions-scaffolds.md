# WP-07 · Actions and scaffolds

**Wave 2. Depends on WP-01 and WP-02. Size: medium.**

**Goal:** finish `CallToActionButton`, and add `.bottomCTA`, `InlineMessage` and
`OnboardingStepScaffold`. This WP does not migrate Core call sites.

**Owns:**
- `Components/Buttons/CallToActionButton.swift`
- `Components/DesignSystem/BottomCTA.swift`, `InlineMessage.swift`, `OnboardingStepScaffold.swift` (new)
- `Components/Modals/CustomModalView.swift` (token-ise only)

## Steps

1. **`CallToActionButton`**
   - Add `isLoading: Bool = false`. While loading, show a `ProgressView` in place of the label at
     the same height, disable the button, and set `.accessibilityValue("Loading")`.
   - Label foreground: `Color.onAccent` for primary, `.primary` for secondary. Remove the
     `colorScheme.backgroundPrimary` hack.
   - Keep the existing init source-compatible. There are 13+ call sites.
2. **`.bottomCTA { … }`**
   - A `safeAreaInset(edge: .bottom)` wrapping a `VStack(spacing: Spacing.s)` with
     `.padding(.bottom, Spacing.s)`.
   - It accepts one or two `CallToActionButton`s, or a CTA plus a plain secondary text button.
   - This settles the audit's "half the onboarding steps add `.padding(.bottom)`" drift. Document
     that callers add no padding of their own.
3. **`InlineMessage(kind:text:)`**
   - Symbol and text: `Symbol.error`/`warning`/`info` from WP-01, coloured `danger`/`warning`/`.secondary`.
   - `Font.rowDetail`, combined into one accessibility element.
   - It replaces raw red `Text` errors inside forms and scanners.
4. **`OnboardingStepScaffold`**
   - Read five or six steps under `Core/Onboarding/` first (Gender, Height, GoalSetting,
     PreferredDiet, Expenditure, NotificationsPermissions) to see the shared shape: a `List`,
     `navigationTitle`, the `#if DEBUG` info toolbar, and a bottom CTA.
   - The scaffold takes:
     - `title`
     - optional `subtitle`, shown as the first section's header text
     - `progress: Double?`, drawn as a thin `ProgressView(value:)` under the nav bar, or as
       `navigationSubtitle("Step x of y")`, whichever reads cleaner on device (decide, and screenshot)
     - `@ViewBuilder content`, the List sections
     - `primary`: title, action, `isEnabled`, `isLoading`
     - optional `secondary`: title and action, shown as a plain text button under the CTA
   - It applies `.navigationBarTitleDisplayMode(.large)`, the dev toolbar, and `.bottomCTA`.
   - It exposes a helper that computes `progress` from the onboarding step enum. Read
     `Core/Onboarding/OnboardingStepRouter.swift` and `UserModel.inferredOnboardingStep` for the
     ordered steps, and add no new ordering source.
   - A preview shows it with option rows (use plain rows if WP-06 has not merged), a picker step,
     and the two-button variant.
5. **`CustomModalView`:** switch to `Radius.xl`, `Spacing` and `Font` tokens. No API change.

**Tests:** if the step-progress helper computes an index from the enum, test it (first, middle
and last step).

**Done when:** it builds, `swiftlint` is clean, and the previews render in light, dark and a
large type size.
