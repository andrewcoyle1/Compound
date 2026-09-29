# WP-15 · Clean up, lock in, document

**Wave 4. Runs alone after every Wave 3 branch is merged. Size: medium.**

**Owns:** everything, since it runs alone.

## Steps

1. **Delete deprecated components.** Build, and there must be zero deprecation warnings left.
   Then delete every type Wave 2 deprecated: `StatItem`, `StatCard`, `.badgeButton`,
   `CustomListCellView`, `CustomLabelButtonView`, `CustomToggleView`, `MetricRow`,
   `TextFieldwUnit*`, `LabeledTextField*`, and any forwarding inits on `AnalyticsCard`.
2. **`ColorScheme+EXT`.** Delete every member the widget does not use; today it uses
   `foregroundSecondary` only. Confirm nothing in `DialedIn/` uses it, and rename what remains
   honestly (for example `inverseLabel`).
3. **SwiftLint custom rules** in `.swiftlint.yml`, as `severity: error`. Exclude the share-card
   folders, the widget and `Components/DesignSystem/` where needed.

   | Rule | Pattern |
   |---|---|
   | `no_corner_radius_modifier` | `\.cornerRadius\(` |
   | `no_foreground_color` | `\.foregroundColor\(` |
   | `no_fixed_font_size` | `\.font\(\.system\(size:` |
   | `no_rgb_color_literal` | `Color\(red:` |
   | `no_bare_with_animation` | `\bwithAnimation\(` outside `ReducedMotionViewModifier.swift` |
   | `accent_spelling` | `Color\.accent\b` and `[(:, ]\.accent\b` (use `.tint` or `Color.accentColor`) |
   | `no_color_scheme_surfaces` | `colorScheme\.(background\|foreground)` |
   | `no_drawn_close_button` | `systemName: "xmark"` inside a `ToolbarItem`. Approximate it with a regex on `Image(systemName: "xmark")`, and allow-list legitimate non-toolbar uses. |

   Fix anything they report. `swiftlint --strict` must stay at zero, because CI runs it.
4. **Strings.**
   - Build to let Xcode extract strings.
   - Add Spanish for every new key the Wave 1–3 reports listed. Mark stale keys removed.
   - Commit `Localizable.xcstrings` once.
   - Raise the US/UK spelling mix WP-08 reported as a question in the final report. Do not change it.
5. **Screenshots.** Regenerate the committed deck (`scripts/screenshots.sh`) and commit it. Make a
   contact sheet of the before and after from `git show <base>:Screenshots/…` for the PR.
6. **Docs.**
   - Add a short "Design system" section to `CLAUDE.md`: where tokens live, the contract file,
     the lint rules, and "use a token or primitive, never a literal".
   - Update the Code Health Baseline numbers.
   - Run `python3 scripts/codebase-map.py` and commit.
   - Mark `docs/ui-audit.md` as resolved, with a pointer to the PR.
7. **Verify.**
   - All three schemes build with zero warnings.
   - The widget scheme builds.
   - Run the full suite once, with `-skip-testing:DialedInUITests`.
   - Run `-only-testing:DialedInUITests` once for onboarding.
   - Then push and open the PR.
