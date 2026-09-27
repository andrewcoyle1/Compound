# Wave 3 migration checklist

Every migration WP (08–14) applies this list to every `*View.swift`, and to the presenter where
noted, in the folders it owns. The WP file adds its scope and its specific issues.

## Before starting

1. Run the screenshot deck into your worktree (`DERIVED=~/.dd-wpNN scripts/screenshots.sh
   <udid>`) and note which `STARTSCREEN_*` screens are yours.
2. Build once and list the deprecation warnings that fall in your folders. That list is your
   to-do; it must be empty at the end.

## For each screen

- [ ] **Container.**
  - Settings and forms use `List` (or `Form` only for pure data entry). Pick one per screen
    family and say which.
  - Dashboards and feeds use `List` with zeroed margins, or `ScrollView`, following the existing
    tab root.
  - Remove `.background(.bar)` under glass toolbars.
- [ ] **Colours.**
  - No raw `.blue`/`.green`/… for a concept that has a token: macros, metrics, status, warmup and
    so on.
  - No `colorScheme.backgroundPrimary`/`Secondary`/`foregroundPrimary`: use `surface`, `canvas`
    and `onAccent`.
  - No `.opacity(N)` fills: use `tintedSurface`.
  - Accent per `CONTRACT.md` § Accent: `.tint` (or `Color.accentColor` where a `Color` is
    needed), `Color.accent` and bare `.accent` retired.
  - Selection, primary actions, links, toggles and non-data progress use the accent.
  - Text on accent fills uses `onAccent`.
  - Fix every entry in `accent-swap-findings.md` that falls in your folders.
- [ ] **Type.** Tokens for numbers, titles and rows. `.font(.system(size:))` on images becomes
  `.iconSize`. Replace deprecated `.foregroundColor`.
- [ ] **Spacing and radius.** Tokens only, continuous corners, no `.cornerRadius(`.
- [ ] **Surfaces.** Hand-rolled cards become `.cardSurface`. Stat displays become `Stat`/`Stat.tile`.
  Capsule badges become `Chip`.
- [ ] **Rows.** Deprecated rows become `ListRow*`/`SelectableRow`. Settings rows that push become
  `ListRowButton`, with the whole row tappable and a chevron.
- [ ] **Inputs.** Deprecated text fields become `NumberField`.
- [ ] **Toolbars.** Dismiss is `Button(role: .close)` in `.cancellationAction`. Confirm is
  `Button(role: .confirm)` in `.confirmationAction`. No drawn `xmark`/`checkmark`, and no "Cancel"
  or "Done" text.
- [ ] **Primary action.** `CallToActionButton` via `.bottomCTA`, one per screen. Replace hand-rolled
  `.glassProminent` body buttons and `.bottomBar` primary buttons. Pick one verb per job across
  your area (for example "Log", not "Log Food"/"Log Foods"/"Add").
- [ ] **Titles.** `.inline` everywhere except tab roots and onboarding. Add a title to any routed
  screen that has none.
- [ ] **Sheets.** Replace router fractions with `.compact`/`.half`/`.full`. Replace native
  `.sheet`/`.presentationDetents` with router calls where the content allows. Remove
  hand-rolled `NavigationStack` wrappers the router makes redundant.
- [ ] **Empty, loading and error states.** Per `CONTRACT.md` § Patterns. Replace `Text("No …")`
  stacks. Replace raw red error text with `InlineMessage`.
- [ ] **Numbers.** Every displayed quantity goes through `Format`. Delete private `formatted()`
  helpers.
- [ ] **Symbols.** Replace literals with `Symbol.*`.
- [ ] **Motion.** Bare `withAnimation`/`.animation(` go through the reduced-motion wrappers with
  `Animation` tokens.
- [ ] **Presenter haptics.** `.success` after save, log or complete, `.error` on failure, and
  `.selection` on segment or picker changes. Replace raw `UI*FeedbackGenerator`. Add or extend a
  presenter test that asserts the haptic through the spy interactor.
- [ ] **Accessibility.**
  - Selection gets `.isSelected`.
  - Status is never colour alone.
  - `onTapGesture` on something that acts like a button becomes a `Button`.
  - Icon-only buttons keep their labels.
  - Charts you touch get an accessibility label and value summary.
- [ ] **Feature components.** Move the `Components/Views/...` modules your WP lists into
  `Core/<feature>/Components/`, unchanged except for tokens. Moving needs no project edit.

## Before reporting

- Zero deprecation warnings in your folders.
- `swiftlint` clean.
- `build-for-testing` green.
- Your changed presenter suites pass.
- Run the screenshot deck again with `--diff`. In the report, list every changed screen with one
  line on what changed, and flag anything that changed unintentionally.
