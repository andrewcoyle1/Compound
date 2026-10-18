import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/training_library/view/workout_template_detail_page.dart'
    show templateTargetsText;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;

/// A shipped mesocycle (Swift `PrebuiltMesocycleDetailView`): its overview
/// and every day's plan, and Start Mesocycle, which saves the user's own
/// copy, makes it their active mesocycle and goes back to the library.
class const PrebuiltMesocycleDetailPage({
  required final String mesocycleId,
  super.key,
}) extends StatefulWidget {
  /// The path under the mesocycle library.
  static const path = 'template/:$idParameter';

  /// The route name.
  static const name = 'prebuiltMesocycleDetail';

  /// The path parameter holding the template's id.
  static const idParameter = 'mesocycleId';

  static const _screen = 'PrebuiltProgramDetailView';

  @override
  State<PrebuiltMesocycleDetailPage> createState() =>
      _PrebuiltMesocycleDetailPageState();
}

class _PrebuiltMesocycleDetailPageState
    extends State<PrebuiltMesocycleDetailPage> {
  late final ProgramsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProgramsCubit>()
      ..appeared(PrebuiltMesocycleDetailPage._screen, _parameters);
  }

  var _starting = false;

  Map<String, Object?> get _parameters => {'program_id': widget.mesocycleId};

  @override
  void dispose() {
    _cubit.disappeared(PrebuiltMesocycleDetailPage._screen, _parameters);
    super.dispose();
  }

  Future<void> _start(Mesocycle mesocycle) async {
    if (_starting) return;
    setState(() => _starting = true);
    final ok = await _cubit.succeeded((c) => c.startPrebuilt(mesocycle));
    if (!mounted) return;
    setState(() => _starting = false);
    if (ok) {
      unawaited(HapticFeedback.successNotification());
      context.pop();
    } else {
      unawaited(HapticFeedback.errorNotification());
      await showFailureAlert(context, context.l10n.programStartFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mesocycle = PrebuiltCatalogue.instance.mesocycles
        .where((mesocycle) => mesocycle.id == widget.mesocycleId)
        .firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final secondary = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return AppScaffold(
      appBar: AppBar(title: mesocycle == null ? null : Text(mesocycle.name)),
      body: SafeArea(
        bottom: false,
        child: mesocycle == null
            ? Center(
                child: LibraryEmptyState(
                  icon: AppSymbols.mesocycle,
                  title: l10n.programNoMesocycles,
                ),
              )
            : LibrarySections(
                children: [
                  AppSection(children: [MesocycleHeader(mesocycle: mesocycle)]),
                  AppSection(
                    header: l10n.onboardingOverview,
                    children: [
                      _value(
                        l10n.programDaysPerMicrocycle,
                        mesocycle.workoutTemplates.length,
                      ),
                      _value(
                        l10n.programWorkoutsPerMicrocycle,
                        workoutCount(mesocycle),
                      ),
                      _value(l10n.programMicrocycles, mesocycle.numMicrocycles),
                      AppListRow(
                        title: l10n.programDeload,
                        accessory: AppListRowValue(
                          deloadTitle(l10n, mesocycle.deload),
                        ),
                      ),
                      AppListRow(
                        title: l10n.programPeriodization,
                        accessory: AppListRowValue(
                          mesocycle.periodisation
                              ? l10n.programOn
                              : l10n.workoutSettingsOff,
                        ),
                      ),
                    ],
                  ),
                  AppSection(
                    header: l10n.programDays,
                    children: [
                      for (final (index, day)
                          in mesocycle.workoutTemplates.indexed)
                        MergeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.l,
                              vertical: AppSpacing.m,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: AppSpacing.xs,
                              children: [
                                Text(
                                  l10n.programDayNumber(index + 1),
                                  style: secondary,
                                ),
                                Text(
                                  day.exercises.isEmpty
                                      ? l10n.programRest
                                      : day.name,
                                  style: AppTextStyles.rowTitle.copyWith(
                                    color: day.exercises.isEmpty
                                        ? scheme.onSurfaceVariant
                                        : scheme.onSurface,
                                  ),
                                ),
                                for (final exercise in day.exercises)
                                  MergeSemantics(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.exercise.name,
                                          style: AppTextStyles.rowDetail
                                              .copyWith(
                                                color: scheme.onSurface,
                                              ),
                                        ),
                                        Text(
                                          templateTargetsText(
                                            context,
                                            exercise.setTargets,
                                          ),
                                          style: secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          if (mesocycle != null)
            AppCtaButton(
              label: l10n.programStartMesocycle,
              isLoading: _starting,
              onPressed: () => unawaited(_start(mesocycle)),
            ),
        ],
      ),
    );
  }

  Widget _value(String title, int value) => AppListRow(
    title: title,
    accessory: AppListRowValue(
      AppFormat.number(
        value,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    ),
  );
}
