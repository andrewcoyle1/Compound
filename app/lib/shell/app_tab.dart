import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// The five root tabs, in the Swift app's order (`TabBarView.swift`), one
/// job each. Each path matches the Swift deep link `compound://tab/<name>`.
enum AppTab {
  today(AppSymbols.today),
  training(AppSymbols.equipment),
  nutrition(AppSymbols.nutrition),
  progress(AppSymbols.analytics),
  social(AppSymbols.friends);

  new(this.icon);

  /// The tab bar glyph.
  final IconData icon;

  /// The route path, which is also the route name.
  String get path => '/$name';

  /// The tab's localized title.
  String label(AppLocalizations l10n) => switch (this) {
    today => l10n.tabToday,
    training => l10n.tabTraining,
    nutrition => l10n.tabNutrition,
    progress => l10n.tabProgress,
    social => l10n.tabSocial,
  };
}
