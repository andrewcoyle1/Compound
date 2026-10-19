import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:compound/workout_editor/cubit/workout_wizard_cubit.dart';
import 'package:compound/workout_editor/view/define_workout_editor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The workout wizard's first screen (Swift `NameWorkoutView`), new or
/// editing the user's workout [workoutId]: the name, then the gym when
/// there is one to choose, then the exercises and Save. Opened over the
/// tab as its cover, so it has the close button.
class const NameWorkoutPage({final String? workoutId, super.key})
    extends StatelessWidget {
  /// The new workout's path under the Training tab.
  static const createPath = 'create-workout';

  /// The new workout's route name, which the wizard's first page carries.
  static const createName = 'createWorkout';

  /// The editor's path under the Training tab.
  static const editPath = 'edit-workout/:$idParameter';

  /// The editor's route name.
  static const editName = 'editWorkout';

  /// The path parameter holding the workout's id.
  static const idParameter = 'workoutId';

  /// Opens the wizard on a new workout.
  static Future<void> create(BuildContext context) =>
      context.pushNamed(createName);

  /// Opens the wizard on the user's workout [workoutId].
  static Future<void> edit(BuildContext context, String workoutId) =>
      context.pushNamed(editName, pathParameters: {idParameter: workoutId});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: app.user.uid,
      child: BlocBuilder<TrainingLibraryBloc, TrainingLibraryState>(
        buildWhen: (previous, current) =>
            previous is! TrainingLibraryLoaded &&
            current is TrainingLibraryLoaded,
        builder: (context, state) {
          final workoutId = this.workoutId;
          if (workoutId != null && state is! TrainingLibraryLoaded) {
            return AppScaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final template = switch (state) {
            TrainingLibraryLoaded(:final library) when workoutId != null =>
              library.userWorkoutTemplates
                  .where((template) => template.workoutId == workoutId)
                  .firstOrNull,
            _ => null,
          };
          return BlocProvider(
            create: (context) => WorkoutWizardCubit(
              uid: app.user.uid,
              template: template,
              library: context.read<TrainingLibraryRepository>(),
              analytics: context.read<AnalyticsRepository>(),
            ),
            child: const NameWorkoutView(),
          );
        },
      ),
    );
  }
}

class NameWorkoutView extends StatefulWidget {
  const new({super.key});

  @override
  State<NameWorkoutView> createState() => _NameWorkoutViewState();
}

class _NameWorkoutViewState extends State<NameWorkoutView> {
  static const _screen = 'NameWorkoutView';

  late final WorkoutWizardCubit _cubit;
  late final _name = TextEditingController(text: _cubit.state.name);

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WorkoutWizardCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    _name.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_cubit.state.canContinue) return;
    final gyms = switch (context.read<TrainingLibraryBloc>().state) {
      TrainingLibraryLoaded(:final library) => library.gyms,
      _ => const <GymProfileModel>[],
    };
    _cubit.continued(gyms);
    unawaited(
      _pushWizardPage(
        context,
        _cubit.state.gym == null
            ? const ChooseGymProfileView()
            : const DefineWorkoutWrapperView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WorkoutWizardCubit>().state;
    return AppScaffold(
      appBar: AppBar(
        leading: AppToolbarButton.close(
          key: const Key('NameWorkout.close'),
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          state.isEditing ? l10n.editorEditWorkout : l10n.editorNameWorkout,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.editorWorkoutName,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('NameWorkout.name'),
                    controller: _name,
                    // A new workout's first job is its name.
                    autofocus: !state.isEditing,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: l10n.editorEnterName,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: _cubit.nameChanged,
                    onSubmitted: (_) => _continue(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            key: const Key('NameWorkout.continue'),
            label: l10n.editorContinue,
            onPressed: state.canContinue ? _continue : null,
          ),
        ],
      ),
    );
  }
}

/// Pushes a later step of the wizard, sharing its state and library.
Future<void> _pushWizardPage(BuildContext context, Widget page) {
  final cubit = context.read<WorkoutWizardCubit>();
  final library = context.read<TrainingLibraryBloc>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: library),
        ],
        child: page,
      ),
    ),
  );
}

/// Choosing the gym the workout is built for (Swift `ChooseGymProfileView`).
class ChooseGymProfileView extends StatefulWidget {
  const new({super.key});

  @override
  State<ChooseGymProfileView> createState() => _ChooseGymProfileViewState();
}

class _ChooseGymProfileViewState extends State<ChooseGymProfileView> {
  static const _screen = 'ChooseGymProfileView';

  late final WorkoutWizardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WorkoutWizardCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gyms = switch (context.watch<TrainingLibraryBloc>().state) {
      TrainingLibraryLoaded(:final library) => library.gyms,
      _ => const <GymProfileModel>[],
    };
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.editorChooseGym)),
      body: SafeArea(
        bottom: false,
        child: LibrarySections(
          children: [
            // Every workout needs a gym.
            if (gyms.isEmpty)
              AppEmptyState(
                icon: AppSymbols.gym,
                title: l10n.editorNoGyms,
                description: l10n.editorNoGymsMessage,
                actionLabel: l10n.onboardingGymTitle,
                onAction: () => unawaited(CreateGymProfilePage.push(context)),
              ),
            AppSection(
              header: l10n.editorChooseGymHeader,
              children: [
                for (final gym in gyms)
                  AppListRowButton(
                    key: Key('ChooseGymProfile.${gym.id}'),
                    title: gym.name,
                    subtitle: l10n.editorActiveEquipment(
                      TrainingLibrary.activeEquipmentCount(gym),
                    ),
                    icon: gym.imageUrl == null ? AppSymbols.gym : null,
                    thumbnail: gym.imageUrl == null
                        ? null
                        : StoredThumbnail(gym.imageUrl),
                    onPressed: () {
                      _cubit.gymChosen(gym);
                      unawaited(
                        _pushWizardPage(
                          context,
                          const DefineWorkoutWrapperView(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The exercises and Save (Swift `DefineWorkoutWrapperView`).
class DefineWorkoutWrapperView extends StatefulWidget {
  const new({super.key});

  @override
  State<DefineWorkoutWrapperView> createState() =>
      _DefineWorkoutWrapperViewState();
}

class _DefineWorkoutWrapperViewState extends State<DefineWorkoutWrapperView> {
  static const _screen = 'DefineWorkoutWrapperView';

  late final WorkoutWizardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WorkoutWizardCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    super.dispose();
  }

  Future<void> _done(BuildContext context, WorkoutWizardState state) async {
    final l10n = context.l10n;
    if (state.status == WorkoutWizardStatus.saved) {
      unawaited(AppHaptics.success());
      // Every screen of the wizard, its first included.
      Navigator.of(context)
        ..popUntil(
          (route) =>
              route.settings.name == NameWorkoutPage.createName ||
              route.settings.name == NameWorkoutPage.editName ||
              route.isFirst,
        )
        ..pop();
      return;
    }
    unawaited(AppHaptics.error());
    await showFailureAlert(context, l10n.editorSaveFailed, l10n.editorTryAgain);
    _cubit.failureShown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WorkoutWizardCubit>().state;
    return BlocListener<WorkoutWizardCubit, WorkoutWizardState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == WorkoutWizardStatus.saved ||
              current.status == WorkoutWizardStatus.failed),
      listener: (context, state) => unawaited(_done(context, state)),
      child: AppScaffold(
        appBar: AppBar(title: Text(state.name)),
        body: SafeArea(
          bottom: false,
          child: DefineWorkoutEditor(
            exercises: state.exercises,
            read: () => _cubit.state.exercises,
            write: _cubit.exercisesChanged,
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('DefineWorkoutWrapper.save'),
              label: l10n.editorSave,
              isLoading: state.status == WorkoutWizardStatus.saving,
              onPressed: state.canSave ? () => unawaited(_cubit.save()) : null,
            ),
          ],
        ),
      ),
    );
  }
}
