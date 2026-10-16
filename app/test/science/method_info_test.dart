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

  test('the expenditure and check-in methods use the Swift sources', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final infos = {
        MethodInfo.adaptiveExpenditure(l10n): 9,
        MethodInfo.energyBalance(l10n): 3,
        MethodInfo.targetProposal(l10n): 4,
        MethodInfo.checkInRules(l10n): 3,
        MethodInfo.macroSplit(l10n): 7,
      };
      for (final MapEntry(key: info, value: sources) in infos.entries) {
        expect(info.title, isNotEmpty);
        expect(info.summary, isNotEmpty);
        expect(info.formula, isNotEmpty);
        expect(info.limitations, isNotEmpty);
        expect(info.ownChoices, isNotEmpty);
        expect(info.citations, hasLength(sources));
      }
    }
    // A book, cited without a DOI or an address, as in Swift.
    expect(Citation.acsm2021.linkText, isNull);
    expect(Citation.macrofactor.isPeerReviewed, isFalse);
  });

  test("Methods & Sources lists Swift's 31 methods, in Swift's order", () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(MethodInfo.all(l10n).keys, [
      'weight-trend',
      'adaptive-expenditure',
      'energy-density',
      'energy-balance',
      'target-proposal',
      'check-in-rules',
      'formula-expenditure',
      'resting-metabolic-rate',
      'thermic-effect-of-food',
      'protein-target',
      'macro-split',
      'calorie-floor',
      'calorie-cycling',
      'weight-change-rate',
      'goal-timeline',
      'goal-progress',
      'training.e1rm',
      'training.smartProgression',
      'training.deload',
      'training.warmups',
      'training.rest',
      'training.tonnage',
      'volume.hardSets',
      'volume.tiers',
      'volume.plannedSets',
      'volume.recommendation',
      'habits.weeklyGoal',
      'habits.stepGoal',
      'habits.adherenceBand',
      'habits.waistToHeight',
      'habits.waistToHip',
    ]);
  });

  test('the energy, training and resting methods use the Swift sources', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final infos = {
        MethodInfo.energyDensity(l10n): 7,
        MethodInfo.smartProgression(l10n): 9,
        MethodInfo.warmupSets(l10n): 2,
        MethodInfo.restIntervals(l10n): 2,
        MethodInfo.restingMetabolicRate(l10n): 8,
        MethodInfo.thermicEffectOfFood(l10n): 1,
      };
      for (final MapEntry(key: info, value: sources) in infos.entries) {
        expect(info.title, isNotEmpty);
        expect(info.summary, isNotEmpty);
        expect(info.formula, isNotEmpty);
        expect(info.limitations, isNotEmpty);
        expect(info.citations, hasLength(sources));
      }
      // Swift names no choices of its own for the digestion share.
      expect(MethodInfo.thermicEffectOfFood(l10n).ownChoices, isNull);
      expect(MethodInfo.restingMetabolicRate(l10n).ownChoices, isNotEmpty);
    }
    // Practitioner books, without a DOI, as in Swift.
    expect(Citation.rippetoe2011.isPeerReviewed, isFalse);
    expect(Citation.wendler2009.linkText, isNull);
    expect(Citation.westerterp2004.linkText, 'doi:10.1186/1743-7075-1-5');
  });
}
