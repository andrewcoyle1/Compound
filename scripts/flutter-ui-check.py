#!/usr/bin/env python3
"""Hold app/lib and compound_charts to the UI contract (docs/specs/flutter/ui-contract.md, rules 2-4).

Feature code styles nothing itself: colours, text styles, padding, radii and durations come from
app_ui's tokens, and Material's buttons, rows and dialogs are wrapped once in app_ui. Every
screen was moved onto app_ui by 19 Oct 2026, so any match fails.

    python3 scripts/flutter-ui-check.py              # fail on any match (CI)
    python3 scripts/flutter-ui-check.py --list RULE  # print each match of one rule
    python3 scripts/flutter-ui-check.py --self-test
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'app' / 'lib'
# Charts draw on app_ui's tokens like any screen.
CHARTS = ROOT / 'app' / 'packages' / 'compound_charts'
# app_ui's widgets play haptics through AppHaptics too; only AppHaptics itself uses Flutter's.
APP_UI = ROOT / 'app' / 'packages' / 'app_ui'

# Not preceded by a letter, so `AppCard(` and `appColors.` don't count as `Card(` and `Colors.`.
_ = r'(?<![A-Za-z_])'

RULES = {
    # Rule 2: tokens only.
    'raw-colour': (_ + r'Color\(0x|' + _ + r'Color\.from(ARGB|RGBO)\(|' + _ + r'Colors\.(?!transparent\b)[a-z]',
                   'context.appColors or the ColorScheme'),
    'text-style': (_ + r'TextStyle\(|' + _ + r'fontSize\s*:|' + _ + r'fontWeight\s*:',
                   'AppTextStyles'),
    'padding-literal': (_ + r'EdgeInsets(Directional)?\.\w+\((\s*|[^)]*?[:,]\s*)\d', 'AppSpacing'),
    'gap-literal': (_ + r'SizedBox\(\s*(height|width)\s*:\s*\d', 'AppSpacing or AppControlSize'),
    'radius-literal': (_ + r'(BorderRadius|Radius)\.circular\(\s*\d', 'AppRadius'),
    'animation-duration': (_ + r'(duration|reverseDuration)\s*:\s*(const\s+)?Duration\(',
                           'AppMotion.durationOf'),
    'icon-literal': (_ + r'Icons\.\w+', 'AppSymbols'),
    'date-format': (_ + r'DateFormat\b|' + _ + r'formatTimeOfDay\(',
                    'AppFormat.date, time, hour or dateTime with context.dateLocale'),
    # Material and Cupertino come through app_ui (material_ui / cupertino_ui). Flutter's own
    # libraries are a second copy whose Theme the app never provides, so they draw stock Material 3.
    'framework-import': (r"package:flutter/(material|cupertino)\.dart", 'package:app_ui/app_ui.dart'),
    # One-time tips are app_ui's AppTip and AppTipScope; only app_ui imports showcaseview.
    'showcase-import': (r"package:showcaseview/", 'AppTip and AppTipScope from app_ui'),
    # Rule 3: no raw Material building blocks in features.
    'material-button': (_ + r'(TextButton|OutlinedButton|ElevatedButton|FilledButton|IconButton)(\.\w+)?\(',
                        'an app_ui button (AppCtaButton, or add one)'),
    'material-row': (_ + r'(ListTile|SwitchListTile|CheckboxListTile|RadioListTile)\(',
                     'AppListRow, AppListRowButton, AppListRowToggle or AppSelectableRow'),
    'material-card': (_ + r'Card\(', 'AppCard'),
    'material-dialog': (_ + r'(showDialog|showModalBottomSheet|showCupertinoDialog|AlertDialog|SimpleDialog)(<[^>]*>)?\(',
                        'an app_ui dialog or sheet (add one)'),
    # Rule 4: haptics play through AppHaptics, which gives Android the iOS patterns.
    'raw-haptic': (_ + r'HapticFeedback\.', 'AppHaptics'),
    # Rule 3: snack bars are app_ui's, drawn above the tab bar.
    'raw-snackbar': (_ + r'(SnackBar|SnackBarAction|showSnackBar)\(', 'showAppSnackBar'),
    # Rule 3: one spinner, app_ui's. A progress indicator given a `value:` shows real progress
    # (a ring or bar filling), so it is not a spinner and does not count.
    'raw-spinner': (_ + r'(CircularProgressIndicator|LinearProgressIndicator)(\.adaptive)?\(|'
                    + _ + r'CupertinoActivityIndicator\(', 'AppSpinner, or AppLoadingView for a first load'),
    # Rule 2: a text style's colour, face or figures come from app_ui, not copyWith on a screen.
    # Only a call that sets one of STYLE_KEYS counts, so a state's copyWith doesn't.
    'style-copywith': (r'\.copyWith\(',
                       'an AppTextStyles style or .secondary(context), .accent(context), '
                       '.onAccent(context), .semibold, .tabular'),
    # Rule 2: an opacity typed in by hand. The greys, separator and tinted fills are tokens.
    'alpha-literal': (r'\.(withValues\(\s*alpha\s*:|withOpacity\(|withAlpha\()',
                      'secondaryLabel, tertiaryLabel, separator, AppColors.tintedSurface or AppColors.muted'),
    # Rule 1: a box drawn by hand. Cards, badges, swatches and selection rings are app_ui's.
    'box-decoration': (_ + r'BoxDecoration\(',
                       'AppCard, AppIconBadge, AppSwatch or AppSelectionRing (or add one to app_ui)'),
    # Rule 3: a tap goes through AppPressable (pressed state, 44 pt target, button semantics). A
    # drag or a swipe keeps its GestureDetector, allowed below.
    'raw-tap': (_ + r'(InkWell|InkResponse|GestureDetector)\(', 'AppPressable'),
    # Rule 3: text entry is app_ui's, so every field types in the same style.
    'raw-text-field': (_ + r'(TextField|TextFormField|CupertinoTextField)(\.\w+)?\(',
                       'AppTextFieldRow, AppTextField, AppSearchField or AppNumberField'),
}

# What a text style's copyWith may not set in app/lib.
STYLE_KEYS = ('color', 'fontSize', 'fontWeight', 'fontFeatures', 'fontFamily', 'letterSpacing',
              'wordSpacing', 'fontStyle', 'shadows')

# Matches a rule lets through in app/lib, as {rule: {path: how many}}, a path ending in / for a
# folder and None for any number. Each has its reason.
ALLOWED = {
    'style-copywith': {
        'app/lib/today/': None,  # design/today removes
        # A keypad key's digits and icon take the key's state (pressed, disabled, selected).
        'app/lib/workout_tracker/view/set_keypad_view.dart': 1,
        # A warm-up set's number and kind chip are in the warm-up colour, the set type's own.
        'app/lib/workout_tracker/view/set_row_parts.dart': 2,
    },
    'alpha-literal': {
        'app/lib/today/': None,  # design/today removes
    },
    'box-decoration': {
        'app/lib/today/': None,  # design/today removes
    },
    'raw-tap': {
        'app/lib/today/': None,  # design/today removes
        # A tap or a horizontal swipe flips consumed and remaining.
        'app/lib/nutrition/view/widgets/macro_header.dart': 1,
        # A horizontal swipe moves the week.
        'app/lib/widgets/calendar/calendar_header.dart': 1,
        # Swiping the banner up dismisses it; its tap is an AppPressable.
        'app/lib/notifications/inbox/view/activity_banner.dart': 1,
        # The target chart's week grid: cells and weekday letters narrower and shorter than 44 pt,
        # in a fixed-height carousel page, that a 44 pt target would push out of it. Each column's
        # cells are also reachable by screen readers as buttons.
        'app/lib/progress/view/progress_carousel.dart': 2,
    },
}

# Generated strings, and share cards, which render to fixed-size images like the Swift app's.
EXEMPT = ('lib/l10n/gen/', 'lib/sharing/share_card/', 'lib/weekly_review/view/weekly_review_share_card.dart')

def determinate(after):
    """Whether the call whose arguments start `after` passes its own `value:`."""
    depth = 0
    for token in re.finditer(r'[()]|' + _ + r'value\s*:', after):
        if token.group() == '(':
            depth += 1
        elif token.group() == ')':
            if depth == 0:
                return False
            depth -= 1
        elif depth == 0:
            return True
    return False


def top_level_keys(after):
    """The named arguments of the call whose arguments start `after`."""
    depth, start = 0, 0
    keys = []
    for token in re.finditer(r'[(\[{]|[)\]}]|(?<![\w.?])(\w+)\s*:(?!:)', after):
        if token.group() in '([{':
            depth += 1
        elif token.group() in ')]}':
            if depth == 0:
                return keys
            depth -= 1
        elif depth == 0:
            keys.append(token.group(1))
    return keys


def allowed(rule, path, count):
    """Whether ALLOWED lets `count` matches of `rule` through in `path`."""
    for prefix, most in ALLOWED.get(rule, {}).items():
        if path == prefix or (prefix.endswith('/') and path.startswith(prefix)):
            return most is None or count <= most
    return False


def matches(text):
    """Yield (rule, line number, line) for every match outside a comment."""
    offset = 0
    for number, line in enumerate(text.splitlines(keepends=True), 1):
        start, offset = offset, offset + len(line)
        if line.lstrip().startswith('//'):
            continue
        for rule, (pattern, _hint) in RULES.items():
            for m in re.finditer(pattern, line):
                if rule == 'raw-spinner' and determinate(text[start + m.end():]):
                    continue
                if rule == 'style-copywith' and not set(top_level_keys(text[start + m.end():])) & set(STYLE_KEYS):
                    continue
                yield rule, number, line.strip()


def scan():
    found = {rule: [] for rule in RULES}
    # Tests must build with the app's Material too, or a widget and its test use different Themes.
    tests = [*(ROOT / 'app' / 'test').rglob('*.dart'), *(CHARTS / 'test').rglob('*.dart')]
    for path in sorted(tests):
        for rule, number, line in matches(path.read_text()):
            if rule in ('framework-import', 'showcase-import'):
                found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
    # Every other package, CHARTS included above.
    for path in sorted((ROOT / 'app' / 'packages').glob('*/*/**/*.dart')):
        package = path.relative_to(ROOT / 'app' / 'packages').parts[0]
        if package in ('app_ui', 'compound_charts'):
            continue
        for rule, number, line in matches(path.read_text()):
            if rule == 'showcase-import':
                found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
    for path in sorted([*LIB.rglob('*.dart'), *(CHARTS / 'lib').rglob('*.dart')]):
        exempt = any(part in path.as_posix() for part in EXEMPT)
        relative = path.relative_to(ROOT).as_posix()
        here = {}
        for rule, number, line in matches(path.read_text()):
            # The clean-up rules hold the screens, not the charts that draw data colours.
            if rule in ALLOWED and path.is_relative_to(CHARTS):
                continue
            # A share card's snack bar is still a screen's.
            if not exempt or rule == 'raw-snackbar':
                here.setdefault(rule, []).append(f'{relative}:{number}: {line}')
        for rule, lines in here.items():
            if not allowed(rule, relative, len(lines)):
                found[rule].extend(lines)
    for path in sorted((APP_UI / 'lib').rglob('*.dart')):
        if path.name == 'app_haptics.dart':
            continue
        for rule, number, line in matches(path.read_text()):
            if rule in ('raw-haptic', 'raw-spinner'):
                found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
    return found


def check():
    found = scan()
    failed = False
    for rule, (_pattern, hint) in RULES.items():
        if found[rule]:
            failed = True
            print(f'{rule}: {len(found[rule])} found. Use {hint}. '
                  f'See docs/specs/flutter/ui-contract.md; list them with --list {rule}.')
    if failed:
        return 1
    print('UI contract: no new literals or raw Material widgets in app/lib or compound_charts.')
    return 0


def self_test():
    cases = {
        "color: Colors.white,": ['raw-colour'],
        "color: Colors.transparent,": [],
        "color: context.appColors.danger,": [],
        "const Color(0xFF112233)": ['raw-colour'],
        "style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),": ['text-style'] * 3,
        "style: AppTextStyles.rowTitle,": [],
        "padding: EdgeInsets.all(12),": ['padding-literal'],
        "padding: EdgeInsets.only(top: 3),": ['padding-literal'],
        "padding: EdgeInsets.all(AppSpacing.l),": [],
        "SizedBox(height: 8),": ['gap-literal'],
        "SizedBox(height: AppSpacing.s),": [],
        "BorderRadius.circular(12)": ['radius-literal'],
        "BorderRadius.circular(AppRadius.m)": [],
        "duration: const Duration(milliseconds: 300),": ['animation-duration'],
        "Icon(Icons.add)": ['icon-literal'],
        "Icon(AppSymbols.add)": [],
        "DateFormat.yMMMd(locale).format(date)": ['date-format'],
        "import 'package:intl/intl.dart' show DateFormat;": ['date-format'],
        "MaterialLocalizations.of(context).formatTimeOfDay(time)": ['date-format'],
        "AppFormat.date(date, locale: context.dateLocale)": [],
        "TextButton(onPressed: f, child: c)": ['material-button'],
        "FilledButton.icon(onPressed: f)": ['material-button'],
        "AppCtaButton(onPressed: f)": [],
        "ListTile(title: t)": ['material-row'],
        "AppListRow(title: t)": [],
        "Card(child: c)": ['material-card'],
        "AppCard(child: c)": [],
        "await showModalBottomSheet<void>(": ['material-dialog'],
        "import 'package:flutter/material.dart';": ['framework-import'],
        "import 'package:flutter/cupertino.dart' show CupertinoPicker;": ['framework-import'],
        "import 'package:flutter/services.dart';": [],
        "import 'package:showcaseview/showcaseview.dart';": ['showcase-import'],
        "// TextButton(onPressed: f) in a comment": [],
        "/// Uses [ListTile( in a doc comment": [],
        "unawaited(HapticFeedback.successNotification());": ['raw-haptic'],
        "unawaited(AppHaptics.success());": [],
        "..showSnackBar(SnackBar(content: Text(message)));": ['raw-snackbar'] * 2,
        "action: SnackBarAction(label: l10n.trackerUndo,": ['raw-snackbar'],
        "showAppSnackBar(context, message, style: AppSnackBarStyle.error);": [],
        "..hideCurrentSnackBar()": [],
        "child: CircularProgressIndicator.adaptive(),": ['raw-spinner'],
        "const CircularProgressIndicator(strokeWidth: 2)": ['raw-spinner'],
        "child: CupertinoActivityIndicator(),": ['raw-spinner'],
        "LinearProgressIndicator(minHeight: 4)": ['raw-spinner'],
        "CircularProgressIndicator(\n  value: fraction,\n  color: c,\n)": [],
        "LinearProgressIndicator(value: progress, color: f(value: 1))": [],
        "CircularProgressIndicator(color: f(value: 1))": ['raw-spinner'],
        "child: AppSpinner(size: AppSpinnerSize.small),": [],
        "style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),": ['style-copywith'],
        "AppTextStyles.rowDetail.copyWith(\n  fontFeatures: const [FontFeature.tabularFigures()],\n)": ['style-copywith'],
        "style: AppTextStyles.label.secondary(context),": [],
        "state.copyWith(status: s, items: [a, b], color: c)": ['style-copywith'],
        "state.copyWith(status: s, items: f(color: c))": [],
        "style.copyWith(decoration: TextDecoration.underline)": [],
        "color: scheme.surface.withValues(alpha: 0.8),": ['alpha-literal'],
        "color.withOpacity(0.5)": ['alpha-literal'],
        "color.withAlpha(128)": ['alpha-literal'],
        "color: AppColors.tintedSurface(color),": [],
        "color.withValues(red: 1)": [],
        "decoration: BoxDecoration(": ['box-decoration'],
        "decoration: const BoxDecoration(color: c),": ['box-decoration'],
        "child: AppSwatch(color: c, selected: true),": [],
        "child: InkWell(onTap: open, child: row),": ['raw-tap'],
        "child: InkResponse(onTap: pick,": ['raw-tap'],
        "return GestureDetector(onTap: open,": ['raw-tap'],
        "child: AppPressable(onTap: open, child: row),": [],
        "child: TextField(controller: c),": ['raw-text-field'],
        "child: TextFormField(initialValue: v,": ['raw-text-field'],
        "CupertinoTextField.borderless(": ['raw-text-field'],
        "AppTextField(hint: h, style: AppTextFieldStyle.plain),": [],
        "maxLength: TextField.noMaxLength,": [],
    }
    for line, expected in cases.items():
        got = [rule for rule, _n, _l in matches(line)]
        assert sorted(got) == sorted(expected), (line, got, expected)
    assert allowed('style-copywith', 'app/lib/today/view/x.dart', 9)
    assert allowed('style-copywith', 'app/lib/workout_tracker/view/set_row_parts.dart', 2)
    assert not allowed('style-copywith', 'app/lib/workout_tracker/view/set_row_parts.dart', 3)
    assert not allowed('style-copywith', 'app/lib/todays/x.dart', 1)
    print(f'self-test: {len(cases)} cases passed')
    return 0


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        sys.exit(self_test())
    if '--list' in sys.argv:
        rule = sys.argv[sys.argv.index('--list') + 1]
        print('\n'.join(scan()[rule]))
        sys.exit(0)
    sys.exit(check())
