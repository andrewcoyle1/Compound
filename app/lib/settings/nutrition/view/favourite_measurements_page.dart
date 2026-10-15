import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/cubit/food_log_settings_cubit.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/nutrition_settings_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The units pinned to serving-size choices (Swift
/// `FavouriteMeasurementsView`): each row pins or unpins its unit.
class FavouriteMeasurementsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'favourite-measurements';
  static const name = 'settingsFavouriteMeasurements';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FoodLogSettingsProvider(
      screen: 'FavouriteMeasurementsView',
      child: Builder(
        builder: (context) {
          final cubit = context.read<FoodLogSettingsCubit>();
          return SettingsDocumentScaffold<
            FoodLogSettingsCubit,
            FoodLogSettings
          >(
            title: l10n.foodLogSettingsFavourites,
            sections: (context, settings) => [
              AppSection(
                header: l10n.favouriteMeasurementsHeader,
                children: [
                  for (final unit in FoodLogSettingsCubit.measurements)
                    AppSelectableRow(
                      title: unit,
                      selected: settings.favouriteMeasurements.contains(unit),
                      onPressed: () => unawaited(cubit.toggleMeasurement(unit)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
