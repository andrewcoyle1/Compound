import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenditureEstimate _estimate({
  ExpenditureSource source = ExpenditureSource.adaptive,
  double? sdKcal = 100,
}) => ExpenditureEstimate(
  day: '2026-10-15',
  kcal: 2450.7,
  source: source,
  isProvisional: source != ExpenditureSource.adaptive,
  trendWeightKg: 80,
  weeklyTrendChangeKg: -0.4,
  loggedDays: 26,
  weighInCount: 24,
  windowDays: 28,
  stepAdjustmentKcal: 0,
  sdKcal: sdKcal,
  weeklyTrendChangeSDKg: null,
  recentIntakeKcal: null,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const locale = 'en';

  test('proposal says which way the target moves', () {
    TargetProposal proposal(double to) => TargetProposal(
      expenditureKcal: 2500,
      currentTargetKcal: 2050,
      proposedTargetKcal: to,
      weeklyTrendChangeKg: null,
      goalWeeklyChangeKg: null,
    );
    expect(
      ExpenditureText.proposal(l10n, proposal(2180), locale: locale),
      '2,180 kcal a day, up from 2,050.',
    );
    expect(
      ExpenditureText.proposal(l10n, proposal(1900), locale: locale),
      '1,900 kcal a day, down from 2,050.',
    );
  });

  test('trendChange rounds to a tenth', () {
    expect(ExpenditureText.trendChange(l10n, null), isNull);
    expect(ExpenditureText.trendChange(l10n, 0.04), 'holding steady');
    expect(
      ExpenditureText.trendChange(l10n, -0.36, locale: locale),
      'down 0.4 kg',
    );
    expect(ExpenditureText.trendChange(l10n, 0.2, locale: locale), 'up 0.2 kg');
  });

  test('expenditure gives the interval, or says it is calibrating', () {
    expect(
      ExpenditureText.expenditure(l10n, _estimate(), locale: locale),
      '2,450 kcal a day, likely 2,323–2,579',
    );
    expect(
      ExpenditureText.expenditure(
        l10n,
        _estimate(source: ExpenditureSource.prior),
        locale: locale,
      ),
      '2,450 kcal a day (calibrating)',
    );
    expect(
      ExpenditureText.expenditure(
        l10n,
        _estimate(source: ExpenditureSource.fixed),
        locale: locale,
      ),
      '2,450 kcal a day',
    );
  });

  test('adherence names the intake and the target', () {
    expect(
      ExpenditureText.adherence(
        l10n,
        const AdherenceNote(
          targetKcal: 1899.6,
          recentIntakeKcal: 2165.4,
          weeklyTrendChangeKg: -0.3,
          goalWeeklyChangeKg: -1,
        ),
        locale: locale,
      ),
      startsWith('You averaged 2,165 kcal a day against a target of 1,900.'),
    );
  });

  test('balance is a deficit, a surplus or balanced', () {
    expect(
      ExpenditureText.balance(
        l10n,
        expenditureKcal: 2500,
        intakeKcal: 2149.6,
        locale: locale,
      ),
      '350 kcal deficit',
    );
    expect(
      ExpenditureText.balance(
        l10n,
        expenditureKcal: 2000,
        intakeKcal: 3200,
        locale: locale,
      ),
      '1,200 kcal surplus',
    );
    expect(
      ExpenditureText.balance(l10n, expenditureKcal: 2000, intakeKcal: 2000.2),
      'Balanced',
    );
  });
}
