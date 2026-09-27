# WP-01 · Tokens

**Wave 1. Depends on nothing. Size: medium.**

**Goal:** create every token in `CONTRACT.md` § Tokens, and make the existing sources of truth
delegate to them. No screen changes appearance, except where a duplicate palette disagreed with
the canonical one.

**Owns:**
- `DialedIn/Components/DesignSystem/` (new)
- `Managers/Nutrition/Models/Macro.swift` (colour members only)
- `Components/Views/Charts/MacroProgressChart.swift` (the two colour extensions only)
- `Extensions/ColorScheme+EXT.swift`
- `SupportingFiles/Assets.xcassets`
- `scripts/screenshots.sh`
- New test files

## Steps

1. **Tooling first.** In `scripts/screenshots.sh`, change `DERIVED="$HOME/.dd-screenshots"` to
   `DERIVED="${DERIVED:-$HOME/.dd-screenshots}"`, so Wave 3 agents can capture in parallel. Commit
   this on its own.
2. **Create the token files.** Create `Spacing.swift`, `Palette.swift`, `Typography.swift` (with
   `IconSize` and `.iconSize(_:)`), `Motion.swift`, `Symbols.swift`, `Format.swift` and
   `Presentation.swift`, exactly as the contract names them. Put a doc comment at the top of each
   file saying when to use which token. Add `#Preview`s that render the palette, type ramp and
   icon sizes in light and dark, so Wave 3 agents can see them.
3. **Fill in the *decide* values.**
   - **Metric colours:** read `Core/Analytics/AnalyticsView.swift` and every `themeColor:` passed
     in Analytics. Assign distinct hues, and record the mapping in a comment table.
   - **Symbols:** grep every `systemImage:` and `systemName:` literal. Cluster them by meaning,
     pick one symbol per concept, and resolve the audit's collisions (`scalemass`, `map`, `book`,
     `list.bullet`, `dumbbell`, the workout icon).
   - **`warmup`, `superset`, `personalRecord`:** pick three distinct hues.
   - Commit the resulting table in `Symbols.swift` as the doc comment.
4. **One macro palette.**
   - `Macro.colour` returns the tokens.
   - Delete `Macro.proteinColor`/`fatColor`/`carbsColor`, both colour extensions in
     `MacroProgressChart.swift`, and `Color.proteinColor` and its siblings.
   - Update every call site of those names to the tokens. This is a mechanical rename, and the
     only Core edits this WP makes.
5. **`ColorScheme+EXT`.** The widget extension compiles this file, and it uses
   `foregroundSecondary` (`WorkoutSessionActivity/LiveActivityView.swift:35`). Leave it working,
   but add a doc comment saying the app uses `Color.surface`/`canvas`/`onAccent`, and that WP-15
   deletes the members the widget does not need.
6. **Format tests.** Write `DialedInUnitTests/DesignSystem/FormatTests.swift` covering each
   `Format` function: rounding boundaries, lb/kg conversion, the placeholder, en dash, and a
   non-English locale for grouping. Look up the existing weight-unit types before writing
   `weight(kg:unit:)`: `ExerciseWeightUnit` (`Managers/Training/Exercise/Models/ExerciseUnitPreference.swift`)
   and `WeightUnitPreference` (`Managers/User/Models/UserModel.swift:466`). Reuse any conversion
   constant that already exists. Do not add a second one.

**Done when:** the app and tests build, `FormatTests` pass, `swiftlint` is clean, and nothing
outside `DesignSystem/` defines a macro colour.

**Commits:** screenshots script · tokens · macro palette consolidation · Format + tests.
