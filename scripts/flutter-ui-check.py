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
                yield rule, number, line.strip()


def scan():
    found = {rule: [] for rule in RULES}
    # Tests must build with the app's Material too, or a widget and its test use different Themes.
    tests = [*(ROOT / 'app' / 'test').rglob('*.dart'), *(CHARTS / 'test').rglob('*.dart')]
    for path in sorted(tests):
        for rule, number, line in matches(path.read_text()):
            if rule == 'framework-import':
                found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
    for path in sorted([*LIB.rglob('*.dart'), *(CHARTS / 'lib').rglob('*.dart')]):
        exempt = any(part in path.as_posix() for part in EXEMPT)
        for rule, number, line in matches(path.read_text()):
            # A share card's snack bar is still a screen's.
            if not exempt or rule == 'raw-snackbar':
                found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
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
    }
    for line, expected in cases.items():
        got = [rule for rule, _n, _l in matches(line)]
        assert sorted(got) == sorted(expected), (line, got, expected)
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
