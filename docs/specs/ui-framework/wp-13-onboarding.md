# WP-13 · Migrate onboarding onto the step scaffold

**Wave 3. Size: large (27 steps), but repetitive.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Onboarding/**`
- `Components/Views/WeeklyMacroChart.swift`, which moves to `Core/Onboarding/Components/`

The sign-in buttons belong to WP-12. Use them as they are.

**Must not change:** step order, routing, or `OnboardingStepRouter`. The UI test
`OnboardingUITests` walks the whole flow and relies on the accessibility identifiers (`Screen.control`).
Keep every identifier. Run the flow once at the end:

```bash
xcodebuild test … -only-testing:DialedInUITests/OnboardingUITests
```

It takes about four minutes.

## Steps

1. **Move every `List`-based step onto `OnboardingStepScaffold`.** Welcome, Auth, Completed and
   StravaConnect are custom `VStack` screens. Give them tokens and `.bottomCTA`, but no scaffold.
   The scaffold removes the per-step dev toolbar, title mode and bottom-CTA code, and the
   inconsistent `.padding(.bottom)`.
2. **Replace the option rows** (Gender, Frequency, Activity, Cardio, PreferredDiet, CalorieFloor,
   ProteinIntake, the goal steps, and any others) with `SelectableRow`. This removes the
   `.onTapGesture` rows in `CalorieFloorView.swift:71` and `ProteinIntakeView.swift:74`, and the
   nested `Section`s in CalorieFloor.
3. **Titles.** One style: questions or nouns. The audit found "How tall are you?" beside
   "Date of birth". Pick question style, which suits onboarding, and apply it to every step's
   title. Use title case consistently.
4. **Pickers.** Height and weight: give both wheels the same width rule. The height wheel is
   capped at 150pt and the weight wheel is not.
5. **Secondary actions.** The "Skip" and "Not now" pattern is identical everywhere: the scaffold's
   `secondary` plain text button. Today StravaConnect has plain text while Notifications and Health
   have a glass CTA.
   - Delete the dead `NotificationsPermissionsView.buttonSection` (`:106`) and the unattached
     `AuthView.toolbarContent` (`:50`).
6. **Colour.**
   - `WeightRateView.swift:79` hardcodes `.green`. Use `accentColor`, or a status token if it
     means "healthy rate".
   - `GoalSummaryView.swift:156` shows a red/green delta. Add a symbol (arrow up or down) so it
     does not rely on colour.
   - `StravaConnectView`'s orange stays: it is Strava's brand. Name it `Color.strava` in the
     step, not in the palette.
7. **Fixed sizes.** Welcome (40), Auth (48), NamePhoto (80) and Strava (72) switch to
   `.iconSize(.hero)` or `Font.display`.
8. **Completed step.** Emoji in the title, `backgroundSecondary`, and a `.tint(.white)` spinner.
   Use `canvas` and `CallToActionButton(isLoading:)`.
9. **`HealthDisclaimerView`.** Its toggles and CTA sit in a `.background(.bar)` panel. Remove the
   bar. The toggles stay `List` rows, and the CTA goes to `.bottomCTA`.
10. **Progress.** Confirm the scaffold's progress indicator shows the right fraction on first,
    middle and last steps. Screenshot all three.
