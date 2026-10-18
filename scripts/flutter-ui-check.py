#!/usr/bin/env python3
"""Hold app/lib to the UI contract (docs/specs/flutter/ui-contract.md, rules 2 and 3).

Feature code styles nothing itself: colours, text styles, padding, radii and durations come from
app_ui's tokens, and Material's buttons, rows and dialogs are wrapped once in app_ui. Code from
before the contract is baselined below. A count may fall but never rise, so no new literal lands.

    python3 scripts/flutter-ui-check.py              # fail if any count is above its baseline (CI)
    python3 scripts/flutter-ui-check.py --list RULE  # print each match of one rule
    python3 scripts/flutter-ui-check.py --self-test

When a count falls, lower its baseline in the same PR so it cannot creep back.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'app' / 'lib'

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
    # Rule 3: no raw Material building blocks in features.
    'material-button': (_ + r'(TextButton|OutlinedButton|ElevatedButton|FilledButton|IconButton)(\.\w+)?\(',
                        'an app_ui button (AppCtaButton, or add one)'),
    'material-row': (_ + r'(ListTile|SwitchListTile|CheckboxListTile|RadioListTile)\(',
                     'AppListRow, AppListRowButton, AppListRowToggle or AppSelectableRow'),
    'material-card': (_ + r'Card\(', 'AppCard'),
    'material-dialog': (_ + r'(showDialog|showModalBottomSheet|showCupertinoDialog|AlertDialog|SimpleDialog)(<[^>]*>)?\(',
                        'an app_ui dialog or sheet (add one)'),
}

# Generated strings, and share cards, which render to fixed-size images like the Swift app's.
EXEMPT = ('lib/l10n/gen/', 'lib/sharing/share_card/', 'lib/weekly_review/view/weekly_review_share_card.dart')

# Counts on 18 Oct 2026, when the contract was written. Lower these as screens are fixed.
BASELINE = {
    'raw-colour': 5,
    'text-style': 83,
    'padding-literal': 1,
    'gap-literal': 1,
    'radius-literal': 6,
    'animation-duration': 1,
    'icon-literal': 6,
    'material-button': 331,
    'material-row': 44,
    'material-card': 0,
    'material-dialog': 104,
}


def matches(text):
    """Yield (rule, line number, line) for every match outside a comment."""
    for number, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith('//'):
            continue
        for rule, (pattern, _hint) in RULES.items():
            for _m in re.finditer(pattern, line):
                yield rule, number, line.strip()


def scan():
    found = {rule: [] for rule in RULES}
    for path in sorted(LIB.rglob('*.dart')):
        if any(part in path.as_posix() for part in EXEMPT):
            continue
        for rule, number, line in matches(path.read_text()):
            found[rule].append(f'{path.relative_to(ROOT)}:{number}: {line}')
    return found


def check():
    found = scan()
    failed = False
    for rule, (_pattern, hint) in RULES.items():
        count, limit = len(found[rule]), BASELINE[rule]
        if count > limit:
            failed = True
            print(f'{rule}: {count}, baseline {limit}. Use {hint}. '
                  f'See docs/specs/flutter/ui-contract.md; list them with --list {rule}.')
        elif count < limit:
            print(f'{rule}: {count}, below its baseline of {limit}. Lower BASELINE in {Path(__file__).name}.')
    if failed:
        return 1
    print('UI contract: no new literals or raw Material widgets in app/lib.')
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
        "TextButton(onPressed: f, child: c)": ['material-button'],
        "FilledButton.icon(onPressed: f)": ['material-button'],
        "AppCtaButton(onPressed: f)": [],
        "ListTile(title: t)": ['material-row'],
        "AppListRow(title: t)": [],
        "Card(child: c)": ['material-card'],
        "AppCard(child: c)": [],
        "await showModalBottomSheet<void>(": ['material-dialog'],
        "// TextButton(onPressed: f) in a comment": [],
        "/// Uses [ListTile( in a doc comment": [],
    }
    for line, expected in cases.items():
        got = [rule for rule, _n, _l in matches(line)]
        assert sorted(got) == sorted(expected), (line, got, expected)
    assert set(RULES) == set(BASELINE)
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
