import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/cubit/create_exercise_cubit.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/create_exercise/view/muscle_group_picker_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Creating a custom exercise (Swift `CreateExerciseView`), over the tabs
/// as Swift's full-screen cover with its own stack: the name and metrics,
/// then the muscles, the equipment, the final details and a review. Create
/// closes the whole flow with the new exercise; it then appears in the
/// library and the picker.
class CreateExercisePage extends StatelessWidget {
  const new({this.prefill, super.key});

  /// The route's path.
  static const path = '/create-exercise';

  /// The route name.
  static const name = 'createExercise';

  /// Opens the flow, on a copy of an exercise when given [prefill]. Completes
  /// with the created exercise, or null when the flow was left.
  static Future<ExerciseModel?> open(
    BuildContext context, {
    ExerciseDraft? prefill,
  }) => context.pushNamed<ExerciseModel>(name, extra: prefill);

  /// What every step starts from: Edit Duplicate's copy.
  final ExerciseDraft? prefill;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: app.user.uid,
      child: BlocProvider(
        create: (context) => CreateExerciseCubit(
          analytics: context.read<AnalyticsRepository>(),
          prefill: prefill,
        ),
        child: const CreateExerciseFlow(),
      ),
    );
  }
}

/// The flow's steps in a navigator of their own, as Swift's cover has its
/// own stack: back steps through them, and Close or Create closes them all
/// with one pop.
class CreateExerciseFlow extends StatefulWidget {
  const new({super.key});

  /// Closes every step of the flow, with the exercise Create made.
  static void close(BuildContext context, [ExerciseModel? created]) => context
      .findAncestorStateOfType<_CreateExerciseFlowState>()!
      ._close(created);

  /// Leaves from the first step, asking first if anything was typed.
  static Future<void> leave(BuildContext context) =>
      context.findAncestorStateOfType<_CreateExerciseFlowState>()!._leave();

  @override
  State<CreateExerciseFlow> createState() => _CreateExerciseFlowState();
}

class _CreateExerciseFlowState extends State<CreateExerciseFlow> {
  final _steps = GlobalKey<NavigatorState>();

  // Past the cover's PopScope: the choice to leave has been made.
  void _close([ExerciseModel? created]) => Navigator.of(context).pop(created);

  Future<void> _leave() async {
    if (!context.read<CreateExerciseCubit>().state.hasUnsavedChanges) {
      return _close();
    }
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepEditingButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardChangesButton),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back steps back through the flow, then leaves it as Close
      // does.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final steps = _steps.currentState!;
        if (steps.canPop()) {
          steps.pop();
        } else {
          unawaited(_leave());
        }
      },
      child: Navigator(
        key: _steps,
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute<void>(builder: (_) => const CreateExerciseView()),
        ],
      ),
    );
  }
}

class CreateExerciseView extends StatelessWidget {
  const new({super.key});

  void _next(BuildContext context) {
    final draft = context.read<CreateExerciseCubit>().continued();
    if (draft == null) return;
    unawaited(pushCreateStep(context, MuscleGroupPickerPage(draft: draft)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CreateExerciseCubit>();
    final state = context.watch<CreateExerciseCubit>().state;
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: AppScaffold(
        appBar: AppBar(
          leading: CloseButton(
            // Anything typed is lost on closing, so it asks first.
            onPressed: () => CreateExerciseFlow.leave(context),
          ),
          title: Text(l10n.createExerciseTitle),
        ),
        body: SafeArea(
          bottom: false,
          child: LibrarySections(
            children: [
              AppSection(
                header:
                    '${l10n.exerciseNameRow} · '
                    '${l10n.createExerciseRequired}',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: TextFormField(
                      key: const Key('CreateExercise.name'),
                      initialValue: state.name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: l10n.createExerciseAddName,
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: cubit.nameChanged,
                    ),
                  ),
                ],
              ),
              AppSection(
                header:
                    '${l10n.createExerciseMetricHeader} · '
                    '${l10n.createExerciseRequired}',
                children: [
                  OptionRow(
                    key: const Key('CreateExercise.metricA'),
                    title: l10n.createExerciseMetricA,
                    value: state.metricA,
                    options: TrackableExerciseMetric.values,
                    name: l10n.metricName,
                    description: l10n.metricDescription,
                    onChanged: cubit.metricAChanged,
                  ),
                  OptionRow(
                    key: const Key('CreateExercise.metricB'),
                    title: l10n.createExerciseMetricB,
                    value: state.metricB,
                    options: TrackableExerciseMetric.values,
                    name: l10n.metricName,
                    description: l10n.metricDescription,
                    onChanged: cubit.metricBChanged,
                  ),
                ],
              ),
              AppSection(
                children: [
                  OptionRow(
                    key: const Key('CreateExercise.type'),
                    title: l10n.filterType,
                    value: state.type,
                    options: ExerciseType.values,
                    name: l10n.exerciseTypeName,
                    onChanged: cubit.typeChanged,
                  ),
                  OptionRow(
                    key: const Key('CreateExercise.laterality'),
                    title: l10n.filterLaterality,
                    value: state.laterality,
                    options: Laterality.values,
                    name: l10n.lateralityName,
                    description: l10n.lateralityDescription,
                    onChanged: cubit.lateralityChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('CreateExercise.next'),
              label: l10n.createExerciseNext,
              onPressed: state.canContinue ? () => _next(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushes a later step of the flow.
Future<void> pushCreateStep(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// Calls [appeared] when shown and [disappeared] when gone, as the Swift
/// views' `onAppear` and `onDisappear` log.
class ScreenAnalytics extends StatefulWidget {
  const new({
    required this.appeared,
    required this.disappeared,
    required this.child,
    super.key,
  });

  final VoidCallback appeared;
  final VoidCallback disappeared;
  final Widget child;

  @override
  State<ScreenAnalytics> createState() => _ScreenAnalyticsState();
}

class _ScreenAnalyticsState extends State<ScreenAnalytics> {
  @override
  void initState() {
    super.initState();
    widget.appeared();
  }

  @override
  void dispose() {
    widget.disappeared();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A row choosing one of [options] or none, each with its [description],
/// in a sheet (Swift's in-row menu `Picker`).
class OptionRow<T extends Object> extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.options,
    required this.name,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String title;
  final T? value;
  final List<T> options;
  final String Function(T) name;
  final String Function(T)? description;
  final ValueChanged<T?> onChanged;

  Future<void> _choose(BuildContext context) async {
    final l10n = context.l10n;
    final description = this.description;
    final chosen = await showModalBottomSheet<(T?,)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l,
          ),
          children: [
            AppSection(
              header: title,
              children: [
                for (final option in <T?>[null, ...options])
                  AppSelectableRow(
                    title: option == null ? l10n.none : name(option),
                    subtitle: option == null ? null : description?.call(option),
                    selected: option == value,
                    onPressed: () => Navigator.of(context).pop((option,)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    unawaited(HapticFeedback.selectionClick());
    onChanged(chosen.$1);
  }

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return AppListRowButton(
      title: title,
      accessory: AppListRowValue(
        value == null ? context.l10n.none : name(value),
      ),
      onPressed: () => unawaited(_choose(context)),
    );
  }
}

/// The descriptions the metric and laterality options carry.
extension on AppLocalizations {
  String metricDescription(TrackableExerciseMetric value) => switch (value) {
    TrackableExerciseMetric.reps => metricRepsDescription,
    TrackableExerciseMetric.repsPerSide => metricRepsPerSideDescription,
    TrackableExerciseMetric.weight => metricWeightDescription,
    TrackableExerciseMetric.weightPerSide => metricWeightPerSideDescription,
    TrackableExerciseMetric.weightPerSidePersistent =>
      metricWeightPerSidePersistentDescription,
    TrackableExerciseMetric.weightPerSideAssistance =>
      metricWeightPerSideAssistanceDescription,
    TrackableExerciseMetric.duration => metricDurationDescription,
    TrackableExerciseMetric.durationPerSide => metricDurationPerSideDescription,
    TrackableExerciseMetric.distanceShort => metricDistanceShortDescription,
    TrackableExerciseMetric.distanceShortPerSide =>
      metricDistanceShortPerSideDescription,
    TrackableExerciseMetric.distanceLong => metricDistanceLongDescription,
  };

  String lateralityDescription(Laterality value) => switch (value) {
    Laterality.bilateral => lateralityBilateralDescription,
    Laterality.unilateral => lateralityUnilateralDescription,
    Laterality.assymetrical => lateralityAssymetricalDescription,
    Laterality.unilateralBilateral => lateralityUnilateralBilateralDescription,
  };
}
