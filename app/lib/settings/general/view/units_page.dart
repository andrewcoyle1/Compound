import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/units_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Weight, height and distance units (Swift `UnitsView`). Each choice saves
/// as it is made.
class UnitsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'units';
  static const name = 'settingsUnits';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => UnitsCubit(
        users: context.read<UserRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        initial: UnitsState.initial(
          state.profile,
          isMetric: usesMetric(
            WidgetsBinding.instance.platformDispatcher.locale.countryCode,
          ),
        ),
      )..appeared(),
      child: const UnitsView(),
    );
  }
}

class UnitsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<UnitsCubit>();
    final state = context.watch<UnitsCubit>().state;
    return OnDispose(
      onDispose: cubit.disappeared,
      child: BlocListener<UnitsCubit, UnitsState>(
        listenWhen: (_, state) => state.saveFailed,
        listener: (context, _) => showAppSnackBar(
          context,
          l10n.unitsSaveFailed,
          style: AppSnackBarStyle.error,
        ),
        child: AppScaffold(
          appBar: AppBar(title: Text(l10n.settingsUnits)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  header: l10n.profileWeightUnits,
                  children: [
                    for (final (unit, title) in [
                      (WeightUnitPreference.kilograms, l10n.unitKilograms),
                      (WeightUnitPreference.pounds, l10n.unitPounds),
                    ])
                      AppSelectableRow(
                        title: title,
                        selected: state.weight == unit,
                        onPressed: () => cubit.weightChanged(unit),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSection(
                  header: l10n.profileHeightUnits,
                  footer: l10n.unitsHeightFooter,
                  children: [
                    for (final (unit, title) in [
                      (LengthUnitPreference.centimeters, l10n.unitCentimeters),
                      (LengthUnitPreference.inches, l10n.unitInches),
                    ])
                      AppSelectableRow(
                        title: title,
                        selected: state.length == unit,
                        onPressed: () => cubit.lengthChanged(unit),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSection(
                  header: l10n.profileDistanceUnits,
                  children: [
                    for (final (unit, title) in [
                      (DistanceUnitPreference.kilometers, l10n.unitKilometers),
                      (DistanceUnitPreference.miles, l10n.unitMiles),
                    ])
                      AppSelectableRow(
                        title: title,
                        selected: state.distance == unit,
                        onPressed: () => cubit.distanceChanged(unit),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
