import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every method names its formula, limits, choices and sources', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final info in [
        MethodInfo.weightTrend(l10n),
        MethodInfo.weeklySessionGoal(l10n),
        MethodInfo.dailyStepGoal(l10n),
        MethodInfo.calorieAdherenceBand(l10n),
      ]) {
        expect(info.title, isNotEmpty);
        expect(info.summary, isNotEmpty);
        expect(info.formula, isNotEmpty);
        expect(info.limitations, isNotEmpty);
        expect(info.ownChoices, isNotEmpty);
        expect(info.citations, isNotEmpty);
        for (final citation in info.citations) {
          expect(citation.linkText, isNotNull);
        }
      }
    }
  });

  test('the habit methods use the Swift sources', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(MethodInfo.weeklySessionGoal(l10n).citations, [
      Citation.bull2020,
      Citation.currier2026,
      Citation.lally2010,
    ]);
    expect(MethodInfo.dailyStepGoal(l10n).citations, [
      Citation.paluch2022,
      Citation.ding2025,
    ]);
    expect(MethodInfo.calorieAdherenceBand(l10n).citations, [Citation.cfr21]);
  });
}
