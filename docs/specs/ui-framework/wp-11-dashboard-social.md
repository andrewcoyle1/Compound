# WP-11 · Migrate Dashboard, social, search and app chrome

**Wave 3. Size: medium.** Apply `wave-3-checklist.md`.

**Owns:**
- `Core/Dashboard/**`, including share cards
- `Core/Challenges/**`
- `Core/Sharing/**`
- `Core/Search/**`
- `Core/Notifications/**`
- `Core/AppView/AppToastView.swift`
- `Core/DevSettings/**`
- `Components/Views/User/**`
- `Components/Views/Nutrition/NutritionCard.swift`, which moves to `Core/Dashboard/Components/`
- `Components/Views/Profile/ProfileButton.swift`
- `Components/Images/`

## Specific issues

- **Card surfaces.** Feed and profile cards hand-roll `backgroundPrimary` + radius 24. Make them
  `.cardSurface`:
  - `WorkoutSessionRowView.swift:61`
  - `InviteFriendCard.swift:46`
  - `SocialProfileView.swift:150,184,209`
  - `CircleWeeklySummaryCard.swift:32`
  - `WeeklyReviewCard.swift:32`
  - `ChallengesDashboardSection.swift:64`
- **`SocialProfileView.swift:204`** is a card-styled empty message. Use `ContentUnavailableView`.
- **Share cards** render to images, so fixed sizes and `.white`/`.black` stay. Only replace their
  duplicated private `stat()` helpers with `Stat`, if the rendered image is unchanged. Compare the
  output in a preview before and after.
- **Toast.** A failure toast is `.orange` (`AppToastView.swift:28`). Make it `danger` with the
  error symbol, and `success` for success.
- **Search.** The private `QuickActionChip` (`SearchView.swift:~311`) becomes `Chip`. Its native
  `.alert` with a `TextField` is the justified exception; keep it.
- **Close buttons.** Notifications and DevSettings put the close `xmark` in `.topBarLeading`. Use
  `role: .close` in `.cancellationAction`.
- **Notifications** uses a `.large` title on a modal. Make it `.inline`.
- **`NutritionCard`.** Its `.bordered` button follows the button rule. Its macro colours already
  come from tokens after WP-01; check them.
- **`ProfileButton.swift:26`** uses a fixed 24pt size. Use `.iconSize(.medium)`.
- **Keep what works.** The feed's accessibility (`WorkoutSessionRowView.swift:76-200`,
  `CircleLeaderboardView.swift:64`) is the reference pattern. Keep it intact.
