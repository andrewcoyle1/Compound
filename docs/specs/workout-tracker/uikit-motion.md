# Workout tracker: UIKit containers, transitions, and motion

This is analysis only; no files in the repo were changed. It follows on from `containers.md`, which covered
SwiftUI containers A1–D3 and concluded that the set table has to stay a List, so a pager has to
use one List per page. This file covers what `containers.md` did not: (1) UIKit containers and custom
pagers, (2) transitions offered instead of containers, and (3) a full motion, haptic and sound spec.
`perf.md` #6 and #7 already flag the List-level animation and the unanimated CTA hide. Section 3
turns those flags into a concrete design.

Markers: **[verified]** means I read it in this repo. **[known]** means established UIKit or
SwiftUI behaviour. **[uncertain]** means it needs a build on iOS 26 to confirm.

Facts from the repo that this file depends on:
- **Animation call sites in the tracker** [verified]. There are three at screen level:
  - `WorkoutTrackerView.swift:96`: the CTA `.transition`.
  - `:99`: `.reducedMotionAnimation(.emphasis, value: canQuickFinish)`.
  - `:100`: `.reducedMotionAnimation(.standard, value: runningRestEnd == nil)`.
  - Both `:99` and `:100` sit on the List, after `.bottomCTA`, so they wrap the List, the
    `safeAreaBar` and the CTA.
  - There are two more in the row: `SetTrackerRowView.swift:94` on the row's VStack, and `:100`
    on the `listRowBackground` opacity.
  - Two are in the keyboard: `SetKeyboardView.swift:34-35`.
  - Nothing else in the tracker animates.
- **Haptics** [verified]:
  - `logSet` plays `.success`.
  - `logSet` validation failure plays `.error`.
  - `onExerciseSelected`, Do Next, Do Later and Reorder play `.selection`.
  - Pause plays `.light`.
  - Rest over plays `.warning` (with a code comment explaining why it is not `.success`).
  - Finish plays `.success`, but only when the asynchronous save returns.
  - A finish failure plays **no** haptic.
  - HapticOption also has `.warning`, `.soft`, `.rigid`, `.medium` and `.heavy`
    (SwiftfulHaptics `HapticOption.swift`).
- **Sound** [verified]. `.restComplete` is prepared when a rest starts and played at rest end.
  The `.wav` file isn't in the bundle yet, so system sound 1007 plays in its place.
- **Rest end** [verified]. `HKWorkoutManager.endRest()` sets `restEndTime = nil`, then posts
  `workoutRestDidComplete` in the same call. The tracker hears it through an `AsyncSequence`, so
  the haptic and sound arrive one task hop after the CTA has flipped.
- **No scroll management** [verified]. The tracker has no `ScrollViewReader`, `scrollTo` or
  `scrollPosition`. A tap on an Up Next row while scrolled down changes the card off-screen.
- **No double-tap guard on the CTA** [verified]. `logSet`'s guard is `completedAt == nil` on
  the set it was given. A fast second tap therefore lands on whatever the slot now says:
  - with rest timers on, **Skip Rest** (the rest is cancelled);
  - with them off, **Log Set N+1** (a set is logged that wasn't performed).
- **Zoom transitions have precedent** [verified]. SwiftfulRouting's `ZoomTransitionWrapper`,
  `showProfileViewZoom`, and `matchedTransitionSource` in five tab roots.
- **`withReducedMotionAnimation` in a presenter has precedent** [verified]:
  `ExpenditurePresenter`.

---

## 1. Containers outside SwiftUI, and custom pagers

### What the earlier analysis turns on, and what UIKit can and cannot change

The pager loses in `containers.md` because a horizontal swipe means two things on the same
surface: on a set row it means "reveal Delete or Rest Timer", and anywhere else on the page it
means "next exercise". HIG gestures: custom gestures must be "Distinct from other gestures", and
the Swipe row of the standard table already covers "Reveal actions and controls".

UIKit gives finer control over the gesture *recognizers*:
- `require(toFail:)`;
- a `UIScrollView` subclass that overrides `gestureRecognizerShouldBegin`;
- `touchesShouldCancel(in:)`.

With these you can make the winner **deterministic**, but you can't make the gesture
**unambiguous** to the person doing it: they still can't tell which of the two they'll get. So
none of the options below changes the conclusion. They only change how the pager fails:
unpredictably in SwiftUI, predictably but confusingly in UIKit.

### U1. `UIPageViewController(.scroll)` hosting a `UIHostingController<List>` per block

- **Gestures.**
  - The page controller's internal scroll view pan competes with the List's swipe-action pan.
    SwiftUI's `.swipeActions` maps to the List's UICollectionView list-cell swipe machinery,
    whose recognizer is private.
  - To arbitrate, you would walk `collectionView.gestureRecognizers` and match on private class
    names, which is fragile and could break with any OS update.
  - Without arbitration, the deeper recognizer usually wins once a touch starts on a cell and
    moves horizontally **[uncertain]**. Pages would then turn only from the header, the margins
    or empty space. On a dense set table that is almost nowhere, so paging becomes unreliable
    rather than dangerous.
  - Turning off `.swipeActions` in paged mode is still required (the context menu already
    carries both actions).
- **Keyboard.** This is the best of all the pager options.
  - Each `UIHostingController` applies the keyboard safe area to its own root **[known]**, which
    resolves `containers.md`'s [uncertain] question about the inset reaching an inner List.
  - Lock paging while editing with the classic `pageVC.dataSource = nil`, and restore it on
    keyboard hide **[known]**.
  - Resign first responder before `setViewControllers` on programmatic moves (the focus is a
    `UIViewRepresentable` first responder, `containers.md` pitfall 9).
- **Selection sync.**
  - `pageViewController(_:didFinishAnimating:previousViewControllers:transitionCompleted:)` is a
    real "settled" callback. It is the right place for the haptic, the `exerciseSelected` event
    and `refreshLiveActivity()`. That's cleaner than `onScrollPhaseChange`.
  - Programmatic moves use `setViewControllers(_:direction:animated:)`, which is direction-aware.
  - Known UIKit bug: an animated `setViewControllers` in `.scroll` style can cache stale
    neighbours. The fix is a non-animated `setViewControllers` in its completion **[known]**.
  - Reorders (Do Later, `onMove`, superset moves) need the same reset, because the data source
    is asked for neighbours lazily.
- **Memory.** Only the current page and its two neighbours are alive, about three
  UICollectionViews. Pages further away are released along with their row `@State`
  (`SetKeyboardInputHost`, `showAutoRanges`), so lift those into the presenter as B1 has to.
- **SwiftUI environment does not cross a manually created `UIHostingController`** **[known]**.
  - `readableContentWidth` (set once in `DialedInApp.swift:36` [verified]), `editMode` and
    `defaultMinListRowHeight` all have to be re-injected into each page's `rootView`.
  - Traits (Dynamic Type, colour scheme, Reduce Motion) do come through `UITraitCollection`.
  - `@Observable` presenter reads work across the boundary.
  - Routers are passed in closures, so they're unaffected.
- **iOS 26 bars.**
  - The glass nav bar's scroll-edge effect follows the scroll view that UIKit finds as content.
    Through a page controller and a hosting controller to SwiftUI's private UICollectionView,
    which one that is is **[uncertain]**.
  - `setContentScrollView(_:for:)` would fix it, but needs that private collection view.
  - `.toolbar` and `.navigationTitle` inside a page do not reach the tracker's nav bar, so keep
    them outside.
- **A11y.** The `.scroll` style supports VoiceOver's three-finger page scroll with an
  announcement **[known, verify on 26]**. That's better than any SwiftUI pager.
- **Cost.** High:
  - a Representable with a Coordinator, a data source, and a hosting-controller cache keyed by
    block id;
  - environment re-injection;
  - stale-neighbour resets;
  - everything B1 already needs: rest-row gating, lifted state, swipe actions off.

### U2. `UICollectionView`, compositional layout, a section with `orthogonalScrollingBehavior = .paging`

- This puts a horizontal pager **inside** a vertical collection view: `containers.md`'s C2 in
  UIKit form.
- A page is a cell, so a set table inside it can't be a List: a List inside a cell has no
  intrinsic height. It would have to be plain `UIHostingConfiguration` content, which loses every
  List modifier (constraint 1).
- Orthogonal sections size to the tallest item when heights are estimated **[known]**, so a
  3-set page and a 6-set page share one height.
- Reject.

### U3. A full-screen horizontal `UICollectionView`, one cell per block, custom paging layout

- **Paging.** Override `targetContentOffset(forProposedContentOffset:withScrollingVelocity:)`.
  This is the apple-design §6 projection: snap to the page nearest
  `current + (v/1000)·d/(1−d)`, with `d ≈ 0.99` for snappier pages.
- **Reorders.** Diffable snapshots animate them well, which is a real plus.
- **Cell reuse is the killer.**
  - A `UIHostingConfiguration` cell that hosts a List gets reused for another block.
  - Whether the List's scroll offset and any `@State` carry over to the wrong exercise or reset
    is **[uncertain]**. Either way the first responder is torn down mid-edit.
- **Keyboard.** Hosting-configuration cells get no keyboard avoidance of their own **[known]**,
  so you'd handle it by hand.
- Reject.

### U4. `UIScrollView(isPagingEnabled)` with child `UIHostingController`s

- **The most control you can get.**
  - Subclass `UIScrollView` and override `gestureRecognizerShouldBegin(_:)` so the page pan
    begins only when:
    - the touch starts outside a set row (header, strip, margins), or
    - the horizontal velocity is three times the vertical and above a threshold.
  - You can't reassign `panGestureRecognizer.delegate` **[known]**; the subclass override is the
    supported route.
  - You get rubber-banding and deceleration for free.
- **Keyboard.** The same as U1: hosting controllers apply their own keyboard inset. Lock with
  `isScrollEnabled = false` while editing.
- **The catch.**
  - The deterministic rule ("page from the header, never from rows") can't be discovered: a
    person swipes on the table, where their thumb is, and nothing happens.
  - That is HIG "consistent with people's expectations" failing in the other direction.
- **Cost.** The highest: containment, layout, lazy windowing, and the U1 environment work.

### U5. A custom SwiftUI pager: `HStack` + `.offset`, `DragGesture`, velocity, rubber-band

What a good one needs (apple-design §§3–9):

```swift
// Drag tracks 1:1; rubber-band past the ends; at release, project, snap, hand off velocity.
.gesture(drag, including: isKeyboardVisible ? .subviews : .all)   // GestureMask locks paging while typing

let drag = DragGesture(minimumDistance: 10)                      // 10 pt hysteresis (§10)
    .onChanged { v in
        let raw = v.translation.width
        dragX = atEnd(raw) ? rubberband(raw, width) : raw          // §9: o·d·c/(d + c·|o|), c = 0.55
    }
    .onEnded { v in
        let projected = -CGFloat(index) * width + v.translation.width
                      + (v.velocity.width / 1000) * 0.99 / (1 - 0.99)          // §6
        let target = clampedNearestPage(projected)
        let remaining = (-CGFloat(target) * width) - (-CGFloat(index) * width + dragX)
        let relV = remaining == 0 ? 0 : v.velocity.width / remaining           // §5
        withReducedMotionAnimation(.interpolatingSpring(stiffness: 300, damping: 34,   // ≈ ζ 1.0, response ≈ 0.36
                                                        initialVelocity: relV)) {
            index = target; dragX = 0
        }
    }
```

Note: `.interpolatingSpring(...)` is a bare spring literal, not a `Motion.swift` token. The
contract's rule is about *how* an animation is applied (through the reduced-motion helpers), and
the snippet does that. Still, it would be the first spring literal outside `Motion.swift`, so it
would need either a new token or an explicit exception.

How it fares:

- **Interruptibility (apple-design §3) is where it falls short.**
  - SwiftUI doesn't expose the *presentation* value of `.offset`.
  - Grab a page mid-settle and the drag starts from the model value (the target), so the page
    jumps.
  - Fixing that means mirroring the offset through `Animatable` or polling frames, which is not
    a reasonable amount of code for this screen. `UIScrollView` (U4) and SwiftUI's own paging
    `ScrollView` (B1) both get this right for free.
- **Coexisting with the List.** The pager wraps Lists: a UICollectionView with vertical scroll
  and horizontal swipe actions.
  - **`.gesture`** (normal priority) on the parent: the List's UIKit pan usually wins on rows,
    and the pager only moves from non-scrolling chrome **[known pain, iOS 18+ unified
    recognizers]**.
  - **`.simultaneousGesture`**: both run, so a diagonal pan scrolls the table *and* moves the
    page. SwiftUI can't cancel the List's scroll once it has begun.
  - **`.highPriorityGesture`**: the drag starves the List's vertical scroll and its swipe
    actions, because `DragGesture` can't "fail if vertical".
  - **The only correct route** is a `UIGestureRecognizerRepresentable` (iOS 18) wrapping a
    `UIPanGestureRecognizer` whose `gestureRecognizerShouldBegin` rejects vertical-dominant
    velocity. That fixes vertical scrolling but still leaves horizontal row swipe against
    horizontal page swipe, so swipe actions must go.
  - **`GestureMask`** (`including:`) is useful only to lock paging while typing. It governs
    SwiftUI gestures, not the List's UIKit swipe recognizer **[uncertain whether it masks
    them]**.
- **Windowing.** Build only `index-1…index+1`, or you're back to B2's N eager Lists.
- **A11y.** You build it all yourself:
  - `.accessibilityScrollAction` for three-finger swipes;
  - `.accessibilityAdjustableAction` on the strip;
  - `accessibilityHidden` for the off-screen pages.
- **Reduce Motion.** Following the finger stays (HIG accessibility allows "Tracking animations
  directly with people's gestures"). The settle and programmatic moves cross-fade
  (`withReducedMotionAnimation` passes nil, so the page jumps; add `.transition(.opacity)` on the
  page container).

### U6. B1 with a custom `ScrollTargetBehavior`

```swift
struct DeliberatePaging: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let page = context.containerSize.width
        let start = (context.originalTarget.rect.minX / page).rounded() * page
        let travelled = target.rect.minX - start
        // Turn the page only on a deliberate fling or a 35% drag; otherwise settle back.
        // Cuts accidental page turns from a row-swipe that started a little diagonally.
        let deliberate = abs(context.velocity.dx) > 0.6 || abs(travelled) > page * 0.35
        target.rect.origin.x = deliberate ? start + (travelled > 0 ? page : -page) : start
    }
}
```

- This only changes *where the scroll lands*. It does nothing about which recognizer wins, so
  it refines B1 rather than offering a new container. Worth adding if B1 ships.
- For the thumbnail strip, the plain `.viewAligned` is enough. Skip a custom behaviour there.

### Scores, on the same six criteria (1–5, cost inverted)

| # | Container | Taps-to-log | Overview | Gesture safety | Keyboard | Cost | A11y | Total |
|---|---|---|---|---|---|---|---|---|
| U1 | UIPageViewController + hosted List per block, swipeActions **kept** | 5 | 4 | 2 | 4 | 2 | 4 | 21 |
| U1′ | U1 with swipeActions **off**, `dataSource = nil` while typing | 5 | 4 | 4 | 4 | 2 | 4 | **23** |
| U2 | Orthogonal paging section in a vertical UICollectionView | 4 | 3 | 2 | 2 | 1 | 2 | 14 |
| U3 | Full-screen horizontal UICollectionView, projection paging, List in hosting-config cells | 5 | 4 | 2 | 2 | 1 | 3 | 17 |
| U4 | Paging UIScrollView subclass + child hosting controllers, rows-never-page rule | 5 | 4 | 3 | 4 | 1 | 3 | 20 |
| U5 | Custom SwiftUI DragGesture pager (best variant: axis-locked UIGestureRecognizerRepresentable) | 5 | 4 | 2 | 3 | 1 | 2 | 17 |
| U6 | B1 + C14 + `DeliberatePaging` | 5 | 4 | 4 | 4 | 3 | 3 | 23 |
| *ref* | `containers.md` B1 + C14 | 5 | 4 | 4 | 4 | 3 | 3 | 23 |
| *ref* | `containers.md` A1 / D1 | 5 | 3 / 5 | 5 | 5 | 5 / 4 | 5 / 4 | 28 |

**Verdict: the earlier conclusion stands.**
- No UIKit container beats B1 + C14, and every one costs more.
- **U1′ is the fallback** if the B1 prototype fails `containers.md`'s [uncertain] keyboard-inset
  check. It has the same score and a more reliable keyboard and settle callback, but pays for
  environment re-injection and has its own edge-effect uncertainty.
- U2, U3 and U5 should not be built.

---

## 2. Transitions between the overview and an exercise, instead of a container

### T1. Zoom push from an Up Next row (`.navigationTransition(.zoom)`)

```swift
// Overview row (tracker root)
exerciseRow(exercise).matchedTransitionSource(id: exercise.id, in: namespace)
// Router: push the exercise screen inside ZoomTransitionWrapper(transitionID: exercise.id, namespace:)
```

- **Feel.** Best-in-class spatial continuity: the row grows into the screen. Dismissal is
  interactive (swipe down from the top, the edge swipe, pinch) and shrinks back into the row
  **[known iOS 18+]**. Reduce Motion is handled by the system **[uncertain exact fallback on 26]**.
- **The source disappears** [verified, and this one is load-bearing].
  - `upNextExercises` filters out `currentExercise`, so the row you zoomed from no longer exists
    once that exercise is current.
  - On the way back the zoom has no target and falls back to the default animation
    **[known]**.
  - To keep the row, the overview has to list every exercise in fixed order. That changes the
    screen's "card on top" model.
- **Every C8 cost carries over** (`containers.md`):
  - a tap in and a back out for every exercise;
  - supersets push and pop on each set;
  - the CTA has to move onto the pushed screen;
  - auto-advance, Do Later on the card and Live Activity logs all need programmatic pop+push
    through the router.
- **Gestures.** The interactive dismiss's swipe down only engages when the List is at its top.
  The edge back-swipe and the leading row swipe (Rest Timer) start in different zones (system
  edge vs inset row) **[uncertain on 26, where content swipe-back works from anywhere]**.

### T2. `matchedGeometryEffect` expansion from row to card

- **Inside one List it doesn't work reliably.** Each row is a separate cell in a
  UICollectionView. The source's geometry is clipped by its cell and reported late
  **[known/uncertain]**.
- **The workable shape is costly.** It would be an overlay `ZStack` with a second List (the
  card) matched to the row's frame. That means:
  - two Lists on screen;
  - either a per-frame relayout of the card List's UICollectionView, or `scaleEffect` blurring
    the set table mid-flight;
  - a hand-written opacity path for Reduce Motion;
  - router sheets presented from rows inside an overlay.
- **Reject.**

### T3. An on-demand sheet with detents for the exercise list

- This is `containers.md`'s D2 (strip + current card + an "All Exercises" sheet holding Up Next,
  Completed and `onMove`), presented through the router with the `.half` preset.
- **Choreography for picking an exercise in the sheet.**
  1. Dismiss first.
  2. Change the card in the dismissal's completion, so the swap happens where the person can
     see it (see the memory note on dismissal order and stale bindings).
  3. Play the `.selection` haptic at the swap, not at the tap.
- **Under Reduce Motion** the sheet's own system animation applies, and the card swap is
  instant.

### T4. One screen per exercise in the `NavigationStack`, plus a persistent bottom strip

- **Persistence.** The tracker's content is the stack's root (RouterView). A `safeAreaBar` there
  does not survive a push.
  - The only native way to make a strip "persistent" is the same `ToolbarItemGroup(placement:
    .bottomBar)` on every pushed screen. The system then morphs the glass between screens.
  - That bottom bar collides with `.bottomCTA`.
- **History semantics are wrong.**
  - Back means "the exercise I last looked at", not "the previous exercise in the workout".
  - Strip taps pile up pushes, unless you *replace* the path. Then it's T5 with more plumbing.
- **Does it beat the list and the pager?** It ties the pager (23) and loses to A1, D1 and D2.
  **No.**

### T5 (new). D2's single-card List, swapped by identity with a directional push

This gives a pager's spatial feel with none of the pager's gestures. The card List is replaced
as a whole when the block changes, and the edge it enters from follows workout order.

```swift
// WorkoutTrackerView: in D2 the main List holds only the current block.
@Environment(\.accessibilityReduceMotion) private var reduceMotion   // already declared, line 15

ZStack {
    List { currentExerciseSection }
        .id(presenter.currentBlockId)                                  // new List per block
        .transition(reduceMotion ? .opacity : .push(from: presenter.blockEntryEdge))
}
.reducedMotionAnimation(.standard, value: presenter.currentBlockId)    // scoped to the card container
.safeAreaBar(edge: .top) { exerciseStrip }                              // containers.md #1
```

`blockEntryEdge` is set in the presenter in the same mutation that changes the block:
`.trailing` when moving forward (Next, Do Later, a strip tap to the right, auto-advance) and
`.leading` when moving back.

**Gotcha** [known]: the outgoing view's removal uses the edge it had at its *last* update. Set
the edge before the id changes, in the same transaction, or the old card exits the wrong way.
`.push(from:)` handles both directions from one value, which `.asymmetric` doesn't.

- **Free wins.**
  - Each new block starts scrolled to the top, which fixes the missing scroll-to-card [verified
    gap].
  - The keyboard resigns on the swap, which is already today's behaviour.
  - The old List is torn down after about 0.5 s.
- **Cost.**
  - Two Lists are alive during the transition.
  - Whether the bar's scroll-edge effect re-attaches to the new List is **[uncertain]**.
    `containers.md` notes that the header's solid `Color.canvas` makes this cosmetic.
- **Supersets.** Use C14 blocks, so the round-robin moves the row highlight inside one card
  instead of pushing a new card on every set.

| # | Transition | Taps-to-log | Overview | Gesture safety | Keyboard | Cost | A11y | Total |
|---|---|---|---|---|---|---|---|---|
| T1 | Zoom push per exercise from Up Next | 3 | 5 | 4 | 5 | 3 | 5 | 25 |
| T2 | matchedGeometryEffect row → card overlay | 4 | 4 | 4 | 3 | 1 | 3 | 19 |
| T3 | Strip + card + on-demand exercise sheet (= D2) | 5 | 4 | 5 | 5 | 4 | 4 | 27 |
| T4 | Push per exercise + per-screen bottom-bar strip | 4 | 4 | 4 | 5 | 2 | 4 | 23 |
| T5 | D2 + `.id(block)` + `.push(from:)` swap | 5 | 4 | 5 | 5 | 4 | 4 | **27** |

T5 scores the same as D2 on these six criteria. What it adds is spatial consistency, which the
table doesn't measure. If D2 ships, T5 adds about 15 lines on top of it. Zoom (T1) is the
right tool for a list of things you open and close. A workout is a sequence you move through.

---

## 3. Motion, haptics and sound

### 3.0 The tokens in Apple's terms

`.snappy`, `.smooth` and `.bouncy` are SwiftUI spring presets, each with a perceptual duration of
0.5 s **[known]**. Apple's damping ratio is ζ = 1 − bounce.

| Token | Is | ζ | Response | apple-design reading |
|---|---|---|---|---|
| `.quick` | `.snappy` | ≈ 0.85 | 0.5 s | Not actually quicker than `.standard`; it only adds a small overshoot. |
| `.standard` | `.smooth` | 1.0 | 0.5 s | The critically damped default. A little slower than Apple's 0.3–0.4 s UI default. |
| `.emphasis` | `.bouncy` | ≈ 0.7 | 0.5 s | apple-design keeps bounce for momentum. The contract keeps it for celebration (a set completed, a PR). The contract wins (CLAUDE.md precedence), so use it on **small elements only**, never a whole List. |
| `.progress` | `easeOut(1.0)` | – | 1.0 s | Fills. Not a spring and not interruptible, which is fine for bars and rings. |

- **No new tokens are needed for this screen.** One optional, app-wide follow-up: make
  `.quick = .snappy(duration: 0.35)` so the name matches the behaviour. Do it as its own change,
  because every caller in the app would move.
- **The two reduced-motion helpers behave differently, and that's right.**
  - `withReducedMotionAnimation` passes `nil` (no animation).
  - The `reducedMotionAnimation` modifier falls back to `.easeInOut(0.2)`. That still *moves*
    things, so it's only a cross-fade when what changes is opacity, colour or a content
    transition.
  - Rule for this screen: List structure changes (row insert, remove or move, a card swap) go
    through `withReducedMotionAnimation`, so Reduce Motion makes them instant. Opacity, colour
    and label changes go through the modifier, so they become a 0.2 s fade. This matches HIG
    accessibility: "Replacing transitions in x-, y-, and z-axes with fades".

### 3.1 Scoping: take animation off the List

**What happens today** [verified at `WorkoutTrackerView.swift:99-100`]:
- Both modifiers wrap the List, its `safeAreaBar` and the CTA. Whenever `runningRestEnd == nil`
  or `canQuickFinish` flips, *every* change in that transaction animates with that curve:
  - the row's done state;
  - the highlight moving;
  - the rest row being inserted;
  - logged warm-ups being removed (they're filtered out at `SetTrackerView.swift:76`);
  - the card swapping on auto-advance or a superset round-robin;
  - Up Next and Completed moving;
  - the header bar.
- Nested `.animation(value:)` modifiers: the inner one, `.emphasis`, wins for the content. On
  the final set with rest on, the **whole List bounces** **[likely; check with Slow Animations]**.
- The same log *with rest timers off* animates nothing except the row background.
- A card change from tapping Up Next (`onExerciseSelected`) doesn't animate at all.
- So the same kinds of change animate or not depending on an unrelated setting.

**Proposal.** Put animation at the cause, and scope the CTA's animation to the CTA.

```swift
// 1. WorkoutTrackerView: delete lines 99–100. One stable CTA view owns its own animation.
.bottomCTA {
    if !isKeyboardVisible, presenter.primaryAction != nil || presenter.runningRestEnd != nil {
        WorkoutPrimaryCTA(presenter: presenter)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
}

// 2. Keyboard flag writes animate, so the transition above actually runs (perf.md #6).
.onReceive(...keyboardWillShow...) { _ in withReducedMotionAnimation(.quick) { isKeyboardVisible = true } }
.onReceive(...keyboardWillHide...) { _ in withReducedMotionAnimation(.quick) { isKeyboardVisible = false } }

// 3. The CTA: ONE CallToActionButton identity for log / next / finish / skip, so the glass capsule
//    morphs its label and width instead of one button sliding out while another fades in.
private struct WorkoutPrimaryCTA: View {
    let presenter: WorkoutTrackerPresenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let restEnd = presenter.runningRestEnd
        HStack(spacing: 0) {
            CallToActionButton {
                restEnd == nil ? presenter.onPrimaryActionPressed() : presenter.onSkipRestPressed()
            } label: {
                if let restEnd {
                    HStack(spacing: Spacing.s) {
                        Text("Skip Rest")
                        Text(timerInterval: Date()...max(Date(), restEnd)).monospacedDigit()   // perf.md #9
                    }
                } else {
                    Label { Text(presenter.primaryActionTitle).lineLimit(2).multilineTextAlignment(.center) }
                    icon: { if presenter.canQuickFinish { Image(systemName: Symbol.success)
                                .symbolEffect(.bounce, value: presenter.canQuickFinish) } }
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                }
            }
            if restEnd != nil {
                Button { presenter.onAddRestTimePressed() } label: { Text("+15s").padding(.vertical, Spacing.m) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Add 15 seconds")
                    .padding(.trailing)
                    // Emerges from, and returns into, the main capsule (apple-design §7).
                    .transition(reduceMotion ? .opacity : .scale(0.85, anchor: .leading).combined(with: .opacity))
            }
        }
        .reducedMotionAnimation(.standard, value: restEnd == nil)       // rest starts / ends
        .reducedMotionAnimation(.emphasis, value: presenter.canQuickFinish) // the finish moment, CTA only
    }
}
// Keep both accessibilityIdentifiers (logButton / skipRestButton) by switching on restEnd;
// UI tests use them.

// 4. Structural List changes animate at the cause. View call sites, so the presenter stays free
//    of SwiftUI (or inside logSet, as ExpenditurePresenter does; both are within the contract):
CallToActionButton action, onLogSet closure (delegate(for:)), exerciseRow tap, Do Next / Do Later
(context menu and card), Reorder:
    withReducedMotionAnimation(.standard) { presenter.… }

// 5. SetTrackerRowView: delete line 94 (the VStack-level animation, which resizes the plate line
//    inside a self-sizing cell; perf.md #7). Keep line 100, the opacity on listRowBackground, so a
//    highlight move from a source without a transaction (e.g. a Live Activity log in the
//    foreground) still fades.
```

Why explicit transactions beat implicit `.animation(value:)` here: every keystroke mutates
`workoutSession` [verified, `primaryActionTitle` comment]. An implicit modifier keyed on a
derived value catches whatever else lands in the same transaction. An explicit transaction
animates only what the person did.

`.contentTransition(.numericText())` morphs only the changed digits of "Log Set 2 · 100 kg × 8".
It applies only when a transaction is animated. Keystrokes aren't animated, so typing updates the
label instantly, which is correct.

### 3.2 The moments

For every moment, haptic and visual land on the same frame (apple-design §13), with **one
haptic per moment**.

**M1. Logging a set** (CTA, row Done, or the keyboard's Done; all go through `logSet`)

- **What moves** (one `.standard` transaction):
  1. The Done symbol becomes `checkmark.circle.fill`. Use
     `.contentTransition(.symbolEffect(.replace))` on the image at
     `SetTrackerRowView.swift:351`. Symbol effects adapt to Reduce Motion themselves **[known]**.
  2. The row dims to its done style (colour only).
  3. The highlight cross-fades from row N to row N+1 (`listRowBackground` opacity; nothing
     slides).
  4. The plate line appears under the new current row, and the cell grows as part of the List's
     animated batch update.
  5. A logged warm-up's row is removed (List delete).
  6. The header bar fills. The counts get `.contentTransition(.numericText())`.
  7. The CTA's digits morph to the next set.
- **What doesn't move:**
  - the scroll position, unless the new current row is under the CTA or off-screen; then
    `proxy.scrollTo(setId, anchor: .center)`, only as far as needed (HIG scroll-views);
  - the card header;
  - the CTA capsule's position.
- **Haptic:** `.success` (exists). **Sound:** none.
- **Reduce Motion:**
  - steps 3 and 7 become 0.2 s fades;
  - steps 4 and 5 are instant;
  - step 1 uses the system's reduced symbol effect.
- **Fix found while tracing: the double tap.**
  - The slot's action changes under the thumb (Log → Skip Rest, or Log N → Log N+1). Ignore
    primary-slot taps for 0.4 s after its *action* changes:
    `guard Date().timeIntervalSince(primarySlotChangedAt) > 0.4`.
  - This doesn't lock out other input. It's the same protection system alerts give their
    buttons.

**M2. Rest starts** (in M1's transaction)

- **What moves:**
  - The inline rest row is inserted under the logged set: a List insert, a fade with the height
    expanding.
  - Its bar is system-driven (`ProgressView(timerInterval:)`) and needs no app animation.
  - The CTA capsule morphs "Log Set 2 · …" into "Skip Rest 1:30" at `.standard`.
  - "+15s" scales out of the capsule's leading edge.
  - The goal is one object changing shape, not two objects trading places. Today the log button
    moves down while Skip Rest fades in [verified at line 96; the HStack has no transition].
- **iOS 26 option:** wrap the CTA in `GlassEffectContainer` with `.glassEffectID` so the two
  glass shapes split like liquid. Whether `glassEffectID` takes effect on `.buttonStyle(.glass)`
  and `.glassProminent` buttons is **[uncertain]**; the plain transition above is the fallback.
- **Haptic:** none. M1's `.success` already covers the moment. **Sound:** the existing
  `prepareSoundEffect` only.

**M3. Rest ends**

- **What moves:**
  - In the rest row, the bar and time become "✓ Ready". Today that swap is unanimated: it's a
    `TimelineView(.explicit)` redraw with no transaction. Inside `InlineRestTimerRow`, add
    `.reducedMotionAnimation(.quick, value: isOver)` and
    `.symbolEffect(.bounce, value: isOver)` on the checkmark: one discrete bounce on a 17 pt
    glyph, the visual beat for the sound.
  - The CTA morphs back from Skip Rest to "Log Set 3 · …", and "+15s" shrinks back into the
    capsule's leading edge. That is M2 reversed, the symmetric path from apple-design §7.
- **What doesn't move:**
  - The rest row stays (as Ready) until the next log. Removing it at rest end would reflow the
    rows under the user's thumb.
  - No scroll, and no card change. HIG collections: no layout change without an explicit action.
- **Haptic:** `.warning` (exists).
  - The HIG says to use system patterns for their documented meaning, and rest-over isn't a
    warning.
  - The repo's reason holds, though: the phone is often on a bench or in a pocket, a single
    impact is easy to miss, and `.success` would blur with M1.
  - Keep it. If it's revisited, the alternative is `.heavy`.
- **Sound:** `.restComplete` (exists; system sound 1007 until the `.wav` ships). Sound and
  vibration have separate settings, as they do today.
- **Harmony:**
  - The CTA flips when `restEndTime = nil`, synchronously in `endRest()`.
  - The haptic and sound arrive through the `notifications(named:)` async sequence, one task hop
    later **[uncertain how far apart; likely within a frame]**.
  - If Instruments shows more than about 16 ms of skew, play the feedback before the state
    clears, for example by having `HKWorkoutManager` post before `cancelRestTimer()`.
- **In the background:** the Live Activity or the notification takes over (existing). No in-app
  animation.
- **Skip Rest:** the rest row is removed and the CTA reverses, as in M3, at `.standard`. No
  haptic: it dismisses something, and the HIG warns against overusing haptics.
- **+15s:** `.selection`, the documented meaning ("values … are changing"). It confirms a tap
  made without looking.

**M4. The card changes exercise**

Causes:
- (a) a tap on an Up Next row;
- (b) the CTA's "Next: …";
- (c) auto-advance after an exercise's last set;
- (d) the superset round-robin;
- (e) Do Later from the card;
- (f) a set logged on the Live Activity.

- **What moves:**
  - Today's List: the card's rows are replaced, and the chosen row leaves Up Next while the old
    card's exercise joins Up Next or Completed, all in one `.standard` transaction (a, b and e
    from the view call site; c and d inherit `logSet`'s).
  - **Give the card one identity per exercise.** Apply `.id(current.id)` to the card content.
    Otherwise the header row (structurally the same view) changes its text in place while the
    set rows fade, which looks half-swapped **[uncertain how `.id` on a Section's content
    behaves inside List; check in a build]**.
  - With T5, the whole card List pushes in from the edge that matches workout order.
- **Scroll** (a missing piece today [verified]):
  - for user-initiated causes (a, b, e), `withReducedMotionAnimation(.standard) {
    proxy.scrollTo(cardTopId, anchor: .top) }`;
  - for automatic ones (c, d), scroll only if the new current set is off-screen.
  - T5 makes this unnecessary.
- **Haptic:**
  - `.selection` for a, b and e (exists).
  - **None** for c and d: M1's `.success` fired in the same moment, and two haptics in one
    moment blur into one (HIG haptics: harmony, avoid overuse).
  - None for f: the person isn't looking.
- **Supersets:** C14 block cards turn (d) from a card swap into an M1-style highlight move
  between the partners' tables. That's the biggest motion win available here. Without it, every
  set swaps the card.
- **Reduce Motion:** the swap is instant and the scroll isn't animated. With T5 the push becomes
  `.opacity`.

**M5. Do Later and Do Next**

- **From an Up Next context menu:**
  - The row moves to its new place in the same Section. The List move animates at `.standard`,
    which is HIG collections' "use animations to provide feedback when people … reorder items".
  - The context menu's own dismissal plays first and then the action runs, so the two don't
    overlap **[known]**.
- **From the card:** M4 (e). The exercise you put off lands at the bottom of Up Next, usually
  off-screen. The scroll goes to the new card, not to where the old one went.
- **Haptic:** `.selection` (exists). Do Later is a reorder, not a completion, so `.success`
  would be wrong.
- **Reduce Motion:** the move is instant.

**M6. Finish**

- **The final set is logged:**
  - M1 runs, plus M2 if rest is on.
  - The CTA becomes "✓ Finish Workout". `.emphasis` is scoped to the CTA: the checkmark gets one
    `.symbolEffect(.bounce)` and the label uses `numericText`/opacity.
  - **The List never bounces.**
  - No extra haptic (the code comment agrees). The existing VoiceOver announcement stays.
- **Tap Finish:**
  - Today `.success` plays when `interactor.finishWorkout` returns, *after* the summary push. A
    retried save plays it again, much later [verified].
  - Proposal: play `.success` in `finishWorkout()` at the commit (`isDone = true` and the
    push), which is what the person sees.
  - Play `.error` with the failure toast. Today a failure is silent [verified], and the contract
    says "`.error` when one fails".
  - Keep `.success` on a *retry* success: the "Workout saved." toast is the visible cause then.
- **The push:** the standard NavigationStack push. A zoom from the CTA into the summary would
  imply the summary *is* the button. Leave the push as it is.
- **Sound:** none.

**M7. Keyboard up or down**

- The CTA slides down and fades (existing transition) at `.quick`, in step with the keyboard.
  The flag writes are wrapped in §3.1 step 2.
- The keyboard's own animation is system-driven.
- **Reduce Motion:** opacity.

### 3.3 Summary table

| Moment | Animation (token → spring) | What moves | What stays | Reduce Motion | Haptic | Sound |
|---|---|---|---|---|---|---|
| M1 log set | explicit `.standard` (ζ1.0, 0.5 s); highlight via modifier | symbol replace, row dim, highlight fade N→N+1, plate line, warm-up row out, bar, CTA digits | scroll (unless needed), header, CTA position | fades; structure instant | `.success` (exists) | – |
| M2 rest starts | same transaction; CTA modifier `.standard` | rest row inserts; capsule morphs to Skip Rest; +15s scales from the leading edge | everything else | +15s and label fade; row instant | – | prepare only |
| M3 rest ends | CTA `.standard`; row `.quick` + one symbol bounce | Ready swap; capsule morphs back; +15s collapses | rest row stays; no scroll | 0.2 s fades | `.warning` (keep) | `.restComplete` |
| Skip / +15s | `.standard` | rest row out; capsule reverts / time jumps | – | instant / fade | – / `.selection` | – |
| M4 card change | explicit `.standard` (T5: `.push(from:)`) | card replaced as a unit; Up Next/Completed rows move | strip and header bar | instant / opacity | `.selection` (user) / none (auto) | – |
| M5 Do Later/Next | explicit `.standard` | List move | card (unless from the card) | instant | `.selection` | – |
| M5 strip drop | `withReducedMotionAnimation(.standard)` | thumbnails move; target ringed while hovered | card | instant | `.selection` on drop | system lift and drag image |
| M6 finish available | CTA-scoped `.emphasis` (ζ≈0.7) | label + one checkmark bounce | **List** | fade + reduced symbol effect | – (M1's) | – |
| M6 finish tap | system push | summary pushes | – | system | `.success` at tap; `.error` on failure | – |
| M7 keyboard | `.quick` | CTA out/in | – | opacity | – | – |

### 3.4 Checks to run once built

- **Simulator, Debug > Slow Animations.** Log a set, then the last set, with rest on and off.
  Expect identical List motion in both, and no bounce in the List.
- **Accessibility > Reduce Motion on.** Expect no y-axis motion: fades and instant structure only.
- **A double tap on the CTA, with rest on and off.** Expect one log, no skip.
- **Instruments' Haptics or os_signpost.** Measure the skew between the CTA flip and the
  `.warning` at rest end.
- **Tests.**
  - `ActiveWorkoutStateTests` covers `onPrimaryActionPressed`. Add one test for the 0.4 s guard,
    which needs an injectable clock or a settable `primarySlotChangedAt`.
  - Add one for `blockEntryEdge` if T5 ships.
