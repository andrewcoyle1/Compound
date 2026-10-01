#!/usr/bin/env python3
"""Regenerates docs/codebase-map.md from the tree. Run from the repo root:

    python3 scripts/codebase-map.py

Everything under the generated marker is derived from file names and a few grep-shaped
regexes, so it never drifts from the tree; the prose above the marker is hand-written and
lives in PROLOGUE below. No dependencies beyond the standard library.
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "codebase-map.md"
TEXT_SUFFIXES = {".swift", ".js", ".py", ".sh", ".md", ".html", ".json", ".yml", ".rules"}
SKIP_DIRS = {"graphify-out", "node_modules", ".build", "DerivedData", "SourcePackages"}

PROLOGUE = """# Compound codebase map

Read this before searching. The tree is regular enough that most paths can be **predicted**
from a name, and the tables below list every screen, manager, model, Cloud Function,
Firestore path and test suite with its file. Regenerate after moving or adding files:

```bash
python3 scripts/codebase-map.py
```

CLAUDE.md holds the rules (build, test, lint, architecture); this file holds the inventory.

## Predicting a path from a name

**A screen called `Foo`** is one folder containing exactly these files. Nothing else in the
app builds or routes it.

| File | Holds |
|---|---|
| `FooInteractor.swift` | `protocol FooInteractor: GlobalInteractor` listing the manager calls the screen needs, then `extension CoreInteractor: FooInteractor { }` (usually empty: `CoreInteractor` already has the members) |
| `FooPresenter.swift` | `@Observable @MainActor class FooPresenter` with `init(interactor:router:)`, every `onXxxPressed()`, and a nested `enum Event: LoggableEvent`. Large presenters split into `FooPresenter+Topic.swift` |
| `FooRouter.swift` | `protocol FooRouter: GlobalRouter` listing the screens this one navigates **to** as `func showBarView(delegate:)`, then `extension CoreRouter: FooRouter { }` |
| `FooView.swift` | `struct FooDelegate` (the inputs), `struct FooView: View` with `@State var presenter`, then `extension CoreBuilder { func fooView(router:delegate:) }` and `extension CoreRouter { func showFooView(delegate:) }` |

So: the `showFooView` a router protocol asks for is **defined at the bottom of `FooView.swift`**,
the builder that makes the screen is right above it, and `CoreRouter.swift` / `CoreBuilder.swift`
in `Root/RIBs/Core` are tiny (they only hold a few shared modals). Reusable VIPER components
(calendar header, exercise list builder, meal accessory) follow the same four-file shape under
`Components/Views`.

**A manager called `FooManager`** lives at `Managers/<Area>/Foo/FooManager.swift` (or
`Managers/Foo/FooManager.swift`), with its models in a sibling `Models/` folder and its
`Mock*`/`Production*`/`Firebase*` services in `Services/`. It is created and registered once in
`Root/Dependencies/Dependencies.swift` (one arm per `BuildConfiguration`) and exposed as a
`let fooManager` on `CoreInteractor`. Package-provided managers (`AuthManager`, `LogManager`,
`PurchaseManager`, `StreakManager`, `HapticManager`, `SoundEffectManager`, the sync engines)
have only an alias file here; see the table in CLAUDE.md.

**A test for `Foo`** is `CompoundUnitTests/**/FooTests.swift` or `FooPresenterTests.swift`, run with
`-only-testing:CompoundUnitTests/FooPresenterTests`. Shared doubles are in `CompoundUnitTests/Support`
(`TestManagers.swift` builds real managers on mock engines; `TestDoubles.swift` has `SpyGlobalInteractor` and
`SpyOnboardingRouter`).

**A Firestore collection** is named in `firestore.rules` (table below), wired in `Dependencies.swift`
through a `FirebaseRemoteCollectionService(collectionPath:)` closure that usually reads the signed-in
uid, and indexed in `firestore.indexes.json`. Adding one means all three plus a deploy.

## Cross-cutting flows

- **Launch**: `CompoundApp` → `AppDelegate.application(_:didFinishLaunchingWithOptions:)` picks
  `BuildConfiguration` from `MOCK`/`DEBUG` flags (or `Utilities.isUITesting`), calls
  `config.configure()` (Firebase, App Check, Google Sign-In's own App Check), builds
  `Dependencies(config:)` → `CoreInteractor` → `CoreBuilder.build()` → `AppView`.
  `AppState.startingModuleId` chooses `Constants.onboardingModuleId` or `tabBarModuleId`.
- **Sign-in and data**: every manager owns a `DocumentSyncEngine`/`CollectionSyncEngine`.
  `CoreInteractor.logIn()` awaits `signIn` on all of them, then seeds prebuilt exercises and
  workouts. `syncAllRemoteDataIfLoggedIn()` only posts `Constants.remoteDataSyncDidComplete`.
- **Navigation**: `SwiftfulRouting`. `GlobalRouter` (`Root/RIBs/GlobalRouter.swift`) gives every
  router `dismissScreen`, `showAlert`, `showLoadingModal`, etc. Cross-tab jumps and push/deep-link
  destinations go through `NotificationCenter` names in `Constants` (`selectTab`,
  `openWorkoutSession`, `openNotifications`, `acceptInvite`) and `Core/TabBar/DeepLink.swift`.
- **Onboarding resume**: `UserModel.inferredOnboardingStep` + `Core/Onboarding/OnboardingStepRouter.swift`.
- **Live Activity / widgets**: app side in `Managers/LiveActivities`, extension in
  `WorkoutSessionActivity/`, shared attributes and storage in `Shared/`. Intents from the island
  reach the app through `AppDelegate.registerLiveActivityIntentHandler`.
- **Siri / Shortcuts**: `Managers/AppIntents` (+ `AppIntentsBridge`), refreshed after data sync.
- **Backend**: `functions/index.js` (callables need App Check + auth, see CLAUDE.md), `firestore.rules`,
  `firestore.indexes.json`, Hosting in `hosting/` with `/s/**` rewritten to `sessionPage`.

## Recipes

- **New screen**: copy any four-file module (e.g. `Core/Onboarding/4 - CompleteAccountSetup/2 - Gender`),
  rename, add `func showFooView(delegate:)` to the *calling* screen's router protocol, add a
  `FooPresenterTests.swift`. Router doubles in tests must implement `showDevSettingsView` unguarded.
- **New manager with a Firestore collection**: model conforming to `DataSyncModelProtocol`, manager taking a sync engine, one registration per arm in
  `Dependencies.swift`, a `let` on `CoreInteractor`, a `Keys.swift.example` manager key, a rules
  block, an index if queried, `TestManagers.swift` wiring, then deploy rules.
- **New Cloud Function**: `onCall(CALLABLE_OPTIONS, …)` opening with `requireAuth(request)`; the
  source check in `functions/index.test.js` fails otherwise. Deploy with `firebase deploy --only functions`.
- **New body measurement**: one field on `BodyMeasurementEntry`, one line in `BodyMeasurementKind`
  (CLAUDE.md, Body Measurements).

"""

AREA_PURPOSE = {
    "Compound/Core/AdaptiveMain": "iPad/Mac split-vs-tab root chooser",
    "Compound/Core/Analytics": "Progress tab: body metrics, exercise/nutrition analytics, insights, consistency",
    "Compound/Core/AppView": "Root view: onboarding-or-tabbar switch, toasts, notification banner",
    "Compound/Core/Challenges": "Group challenges (create, detail)",
    "Compound/Core/Social": "Social tab: workout feed, circle goals, challenges, people search, invites, share card, profiles",
    "Compound/Core/Today": "Today tab: today's workout, nutrition, weigh-in, streak, weekly check-in and weekly review",
    "Compound/Core/DevSettings": "DEV/MOCK-only developer tools screen",
    "Compound/Core/Notifications": "Activity notifications inbox",
    "Compound/Core/Nutrition": "Nutrition tab: meal log, foods, recipes, check-in, library picker, AI scanners",
    "Compound/Core/Onboarding": "Numbered onboarding steps 0–9 (see OnboardingStepRouter)",
    "Compound/Core/Paywalls": "Paywall screens",
    "Compound/Core/Profile": "Profile tab and every settings screen (training, nutrition, general, account, legal)",
    "Compound/Core/Sharing": "Share-to-follower and shared-item viewer",
    "Compound/Core/SplitViewContainer": "iPad sidebar container",
    "Compound/Core/TabBar": "Tab bar, DeepLink parsing, tab selection",
    "Compound/Core/Training": "Training tab: workouts, tracker, programs, history, create flows",
    "Compound/Components": "Reusable views, buttons, modals, charts (QuickCharts alias), view modifiers",
    "Compound/Managers": "App-owned managers, models and services (see Managers table)",
    "Compound/Root": "AppDelegate, CompoundApp, Dependencies DI root, CoreInteractor/Builder/Router, Global protocols",
    "Compound/Utilities": "Constants, Keys, NetworkMonitor, App Check factory, unit conversion, helpers",
    "Compound/Extensions": "Foundation/SwiftUI type extensions (`X+EXT.swift`)",
    "Compound/SupportingFiles": "Assets, entitlements, GoogleService plists, privacy manifest, seed JSON",
    "Shared": "Code compiled into both the app and the Live Activity extension",
    "WorkoutSessionActivity": "Live Activity / Dynamic Island / home widget extension",
    "CompoundUnitTests": "Swift Testing unit suites (BlueprintName CompoundUnitTests)",
    "CompoundUITests": "XCUITest smoke and create-flow tests (launch via STARTSCREEN)",
    "functions": "Firebase Cloud Functions v2 (Node ESM, Genkit/Vertex)",
    "hosting": "Firebase Hosting landing page",
    "scripts": "Screenshot, contact-sheet, smoke-test generation, this map",
    "docs": "Specs, reviews, audits, this map",
}


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def swift_files(base: Path):
    for p in sorted(base.rglob("*.swift")):
        if SKIP_DIRS.isdisjoint(p.parts):
            yield p


def line_count(p: Path) -> int:
    try:
        return sum(1 for _ in p.open(encoding="utf-8", errors="ignore"))
    except OSError:
        return 0


def link(p: Path, label: str | None = None) -> str:
    r = rel(p)
    return f"[{label or p.name}]({r.replace(' ', '%20')})"


# --- areas -------------------------------------------------------------------------------

def area_table() -> str:
    rows = []
    for area in AREA_PURPOSE:
        base = ROOT / area
        if not base.exists():
            continue
        files = [f for f in base.rglob("*") if f.is_file() and SKIP_DIRS.isdisjoint(f.parts)]
        lines = sum(line_count(f) for f in files if f.suffix in TEXT_SUFFIXES)
        rows.append(f"| `{area}` | {len(files)} | {lines:,} | {AREA_PURPOSE[area]} |")
    return "| Area | Files | Lines | Purpose |\n|---|---:|---:|---|\n" + "\n".join(rows)


# --- screens -----------------------------------------------------------------------------

PROTO_SHOW = re.compile(r"^\s*func (show\w+)\(")
DEF_SHOW = re.compile(r"^\s*func (show\w+)\(.*\{\s*$")
DEF_BUILD = re.compile(r"^\s*func (\w+View)\(.*router: AnyRouter.*\{\s*$")
DELEGATE = re.compile(r"^\s*struct (\w+Delegate)\b")
STD_SUFFIX = ("Interactor", "Presenter", "Router", "View")


def short_route(name: str) -> str:
    name = name[len("show"):]
    return name[:-len("View")] if name.endswith("View") else name


def screen_tables(test_index: dict[str, Path]) -> str:
    modules: dict[Path, dict] = {}
    for p in swift_files(ROOT / "Compound"):
        m = re.fullmatch(r"(\w+)Presenter\.swift", p.name)
        if not m:
            continue
        modules[p.parent] = {"name": m.group(1), "dir": p.parent}

    for info in modules.values():
        d, name = info["dir"], info["name"]
        files = sorted(f for f in d.glob("*.swift"))
        info["lines"] = sum(line_count(f) for f in files)
        std = {f"{name}{s}.swift" for s in STD_SUFFIX}
        info["extra"] = [f.name for f in files if f.name not in std]
        routes, shows, builds, delegates = [], [], [], []
        for f in files:
            in_proto = f.name == f"{name}Router.swift"
            for line in f.open(encoding="utf-8", errors="ignore"):
                if in_proto and PROTO_SHOW.match(line) and not DEF_SHOW.match(line):
                    r = PROTO_SHOW.match(line).group(1)
                    if r != "showDevSettingsView":
                        routes.append(short_route(r))
                if (mm := DEF_SHOW.match(line)):
                    shows.append(mm.group(1))
                if (mm := DEF_BUILD.match(line)):
                    builds.append(mm.group(1))
                if (mm := DELEGATE.match(line)):
                    delegates.append(mm.group(1))
        info["routes"] = sorted(set(routes))
        info["shows"] = sorted(set(shows))
        info["builds"] = sorted(set(builds))
        info["delegates"] = sorted(set(delegates))
        exact = [t for k, t in test_index.items() if k.startswith(f"{name}Presenter")]
        loose = [t for k, t in test_index.items() if k.startswith(name) and "Presenter" in k]
        info["tests"] = sorted(t.name for t in (exact or loose))

    groups: dict[str, list] = defaultdict(list)
    for d, info in modules.items():
        parts = rel(d).split("/")
        group = "/".join(parts[:3]) if parts[1] == "Core" else "/".join(parts[:2])
        groups[group].append(info)

    out = []
    for group in sorted(groups):
        out.append(f"\n### `{group}` ({len(groups[group])} modules)\n")
        out.append("| Module | Folder | Lines | Routes to | Delegate / entry | Extra files | Tests |")
        out.append("|---|---|---:|---|---|---|---|")
        for info in sorted(groups[group], key=lambda i: rel(i["dir"])):
            d = info["dir"]
            entry = ", ".join(info["delegates"] + [f"`{s}`" for s in info["shows"]])
            out.append(
                f"| **{info['name']}** | {link(d, rel(d).removeprefix(group + '/') or '.')} | {info['lines']} "
                f"| {', '.join(info['routes'])} | {entry} | {', '.join(info['extra'])} | {', '.join(info['tests'])} |"
            )
    return f"{len(modules)} presenter-backed modules.\n" + "\n".join(out)


# --- managers ----------------------------------------------------------------------------

def manager_table(test_index: dict[str, Path]) -> str:
    rows = []
    for p in swift_files(ROOT / "Compound" / "Managers"):
        m = re.fullmatch(r"(\w+Manager)\.swift", p.name)
        if not m:
            continue
        name = m.group(1)
        d = p.parent
        extras = sorted(f.name for f in d.glob(f"{name}+*.swift"))
        models = sorted(f.stem for f in (d / "Models").glob("*.swift")) if (d / "Models").exists() else []
        if not models and (d / "Model").exists():
            models = sorted(f.stem for f in (d / "Model").rglob("*.swift"))
        services = sorted(f.stem for f in (d / "Services").glob("*.swift")) if (d / "Services").exists() else []
        tests = sorted(t.name for k, t in test_index.items() if k.startswith(name))
        engines = set()
        for line in p.open(encoding="utf-8", errors="ignore"):
            for e in re.findall(r"(Collection(?:Group)?SyncEngine|DocumentSyncEngine)<(\w+)>", line):
                engines.add(f"{e[0].replace('SyncEngine', '')}<{e[1]}>")
        if len(models) > 10:
            models = models[:10] + [f"… +{len(models) - 10} more"]
        rows.append(
            f"| **{name}** | {link(p, rel(d))} | {line_count(p)} | {', '.join(sorted(engines))} "
            f"| {', '.join(models)} | {', '.join(services)} | {', '.join(extras)} | {', '.join(tests)} |"
        )
    return (
        "| Manager | Folder | Lines | Sync engines | Models (sibling folder) | Services | Extensions | Tests |\n"
        "|---|---|---:|---|---|---|---|---|\n" + "\n".join(rows)
    )


def sync_model_table() -> str:
    rows = []
    pat = re.compile(r"^\s*(?:public |final )*(struct|class) (\w+)\s*:[^{]*DataSyncModelProtocol")
    for p in swift_files(ROOT / "Compound"):
        for line in p.open(encoding="utf-8", errors="ignore"):
            if (m := pat.match(line)):
                rows.append(f"| `{m.group(2)}` | {link(p, rel(p))} |")
    return "| Model | File |\n|---|---|\n" + "\n".join(sorted(rows))


def core_interactor_table() -> str:
    rows = []
    for p in sorted((ROOT / "Compound/Root/RIBs/Core").glob("*.swift")):
        rows.append(f"| {link(p)} | {line_count(p)} |")
    return "| File | Lines |\n|---|---:|\n" + "\n".join(rows)


# --- backend -----------------------------------------------------------------------------

def functions_table() -> str:
    rows = []
    src = ROOT / "functions" / "index.js"
    pat = re.compile(r"^export const (\w+) = (\w+)\(")
    for n, line in enumerate(src.open(encoding="utf-8"), 1):
        if (m := pat.match(line)):
            rows.append(f"| `{m.group(1)}` | {m.group(2)} | [index.js:{n}](functions/index.js#L{n}) |")
    return "| Export | Kind | Line |\n|---|---|---|\n" + "\n".join(rows)


def rules_table() -> str:
    rows = []
    stack: list[str] = []
    src = ROOT / "firestore.rules"
    for n, line in enumerate(src.open(encoding="utf-8"), 1):
        s = line.strip()
        if (m := re.match(r"match (\S+) \{", s)):
            path = m.group(1)
            if path.startswith("/databases"):
                stack = []
                continue
            full = "".join(stack) + path
            stack.append(path)
            rows.append(f"| `{full}` | [rules:{n}](firestore.rules#L{n}) |")
        elif s == "}" and stack:
            stack.pop()
    return "| Path | Rules |\n|---|---|\n" + "\n".join(rows)


# --- tests -------------------------------------------------------------------------------

def test_index() -> dict[str, Path]:
    return {p.stem: p for p in swift_files(ROOT / "CompoundUnitTests") if p.stem.endswith("Tests")}


def tests_table(index: dict[str, Path]) -> str:
    by_dir: dict[str, list[str]] = defaultdict(list)
    for stem, p in index.items():
        by_dir[rel(p.parent)].append(stem)
    out = []
    for d in sorted(by_dir):
        names = ", ".join(f"`{s}`" for s in sorted(by_dir[d]))
        out.append(f"**`{d}`** ({len(by_dir[d])}): {names}\n")
    ui = ", ".join(f"`{p.stem}`" for p in sorted((ROOT / "CompoundUITests").glob("*.swift")))
    out.append(f"**`CompoundUITests`**: {ui}\n")
    return "\n".join(out)


def misc_table() -> str:
    rows = []
    for pattern in ("scripts/*", "docs/**/*.md", ".github/workflows/*", "functions/*.js", "functions/scripts/*"):
        for p in sorted(ROOT.glob(pattern)):
            if p.is_file() and p.name != OUT.name:
                rows.append(f"| {link(p, rel(p))} | {line_count(p)} |")
    return "| File | Lines |\n|---|---:|\n" + "\n".join(rows)


def main() -> None:
    tests = test_index()
    body = "\n\n".join([
        "<!-- generated below this line by scripts/codebase-map.py; edit PROLOGUE in the script, not here -->",
        "## Areas\n\n" + area_table(),
        "## Screens and VIPER components\n\n"
        "Each row is one folder holding `<Module>{Interactor,Presenter,Router,View}.swift`. "
        "*Routes to* is what the module's router protocol can open; *Delegate / entry* is the input struct "
        "and the `showXView` defined at the bottom of its View file; *Extra files* are presenter splits and helper views.\n"
        + screen_tables(tests),
        "## Managers\n\n" + manager_table(tests),
        "## Sync models (`DataSyncModelProtocol`)\n\n" + sync_model_table(),
        "## CoreInteractor and its extensions\n\n" + core_interactor_table(),
        "## Cloud Functions (`functions/index.js`)\n\n" + functions_table(),
        "## Firestore paths (`firestore.rules`)\n\n" + rules_table(),
        "## Unit test suites\n\n" + tests_table(tests),
        "## Scripts, docs, CI, backend files\n\n" + misc_table(),
    ])
    OUT.write_text(PROLOGUE + body + "\n", encoding="utf-8")
    print(f"wrote {rel(OUT)} ({line_count(OUT)} lines)")


if __name__ == "__main__":
    sys.exit(main())
