import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/settings/nutrition/cubit/food_log_settings_cubit.dart';
import 'package:compound/settings/nutrition/view/nutrition_settings_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One switch on a Food Log sub-screen: the field it writes, how it reads
/// the stored value, and its words.
typedef FoodLogToggle = ({
  String key,
  bool Function(FoodLogSettings settings) read,
  String title,
  String subtitle,
});

/// A Food Log sub-screen that is a single list of switches (Swift
/// `LoggerBannerView`, `LoggerFoodTilesView`, `TimelineFoodTilesView`).
class FoodLogTogglesView extends StatelessWidget {
  const new({required this.title, required this.toggles, super.key});

  final String title;
  final List<FoodLogToggle> toggles;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FoodLogSettingsCubit>();
    return SettingsDocumentScaffold<FoodLogSettingsCubit, FoodLogSettings>(
      title: title,
      sections: (context, settings) => [
        AppSection(
          children: [
            for (final toggle in toggles)
              AppListRowToggle(
                title: toggle.title,
                subtitle: toggle.subtitle,
                value: toggle.read(settings),
                onChanged: (value) => unawaited(cubit.set(toggle.key, value)),
              ),
          ],
        ),
      ],
    );
  }
}
