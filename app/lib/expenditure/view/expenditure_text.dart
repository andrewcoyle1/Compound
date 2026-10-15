import 'package:app_ui/app_ui.dart' show AppFormat;
import 'package:compound/l10n/l10n.dart';
import 'package:compound_maths/compound_maths.dart';

/// The words around the engine's figures, shared by the check-in, the
/// Nutrition Overview, Today and the Progress tab.
abstract final class ExpenditureText {
  static String _whole(num value, String? locale) =>
      AppFormat.number(value.truncate(), locale: locale);

  /// "2,180 kcal a day, up from 2,050." (`proposalSummary`).
  static String proposal(
    AppLocalizations l10n,
    TargetProposal proposal, {
    String? locale,
  }) {
    final proposed = _whole(proposal.proposedTargetKcal, locale);
    final current = _whole(proposal.currentTargetKcal, locale);
    return proposal.proposedTargetKcal > proposal.currentTargetKcal
        ? l10n.proposalSummaryUp(proposed, current)
        : l10n.proposalSummaryDown(proposed, current);
  }

  /// "down 0.4 kg" a week, "holding steady", or null while there is no
  /// trend (`trendChangeDescription`).
  static String? trendChange(
    AppLocalizations l10n,
    double? weeklyKg, {
    String? locale,
  }) {
    if (weeklyKg == null) return null;
    final rounded = (weeklyKg * 10).round() / 10;
    if (rounded == 0) return l10n.checkInTrendSteady;
    final kg = AppFormat.number(
      rounded.abs(),
      maxFractionDigits: 1,
      locale: locale,
    );
    return rounded < 0 ? l10n.checkInTrendDown(kg) : l10n.checkInTrendUp(kg);
  }

  /// "2450 kcal a day", with the 80% interval once adaptive, or a note that
  /// it is still the formula's (`expenditureDescription`).
  static String expenditure(
    AppLocalizations l10n,
    ExpenditureEstimate estimate, {
    String? locale,
  }) {
    final kcal = _whole(estimate.kcal, locale);
    final range = estimate.likelyRange;
    if (range != null) {
      return l10n.checkInExpenditureRange(
        kcal,
        _whole(range.low, locale),
        _whole(range.high, locale),
      );
    }
    return estimate.source == ExpenditureSource.prior
        ? l10n.checkInExpenditureCalibrating(kcal)
        : l10n.checkInExpenditureValue(kcal);
  }

  /// Why the target stays where it is (`adherenceSummary`).
  static String adherence(
    AppLocalizations l10n,
    AdherenceNote note, {
    String? locale,
  }) => l10n.checkInAdherence(
    _whole(note.recentIntakeKcal.round(), locale),
    _whole(note.targetKcal.round(), locale),
  );

  /// "350 kcal deficit", "120 kcal surplus" or "Balanced"
  /// (`EnergyBalanceSummary.balanceText`).
  static String balance(
    AppLocalizations l10n, {
    required double expenditureKcal,
    required double intakeKcal,
    String? locale,
  }) {
    final value = (expenditureKcal - intakeKcal).round();
    if (value > 0) {
      return l10n.energyBalanceKcalDeficit(
        AppFormat.number(value, locale: locale),
      );
    }
    if (value < 0) {
      return l10n.energyBalanceKcalSurplus(
        AppFormat.number(-value, locale: locale),
      );
    }
    return l10n.energyBalanceBalanced;
  }
}
