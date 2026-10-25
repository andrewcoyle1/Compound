import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/cubit/final_exercise_details_cubit.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/create_exercise/view/exercise_save_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Range of motion, stability, the body weight contribution, other names
/// and a description (Swift `FinalExerciseDetailsView`).
class FinalExerciseDetailsPage extends StatelessWidget {
  const new({required this.draft, super.key});

  final ExerciseDraft draft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FinalExerciseDetailsCubit(
        draft: draft,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const FinalExerciseDetailsView(),
    );
  }
}

class FinalExerciseDetailsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FinalExerciseDetailsCubit>();
    final state = context.watch<FinalExerciseDetailsCubit>().state;
    final draft = state.draft;
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.createExerciseFinalDetails)),
        body: SafeArea(
          bottom: false,
          child: LibrarySections(
            children: [
              AppSection(
                children: [
                  _RatingStepper(
                    title: l10n.filterRangeOfMotion,
                    value: draft.rangeOfMotion,
                    onChanged: cubit.rangeOfMotionChanged,
                  ),
                  _RatingStepper(
                    title: l10n.filterStability,
                    value: draft.stability,
                    onChanged: cubit.stabilityChanged,
                  ),
                ],
              ),
              AppSection(
                header: l10n.exerciseBodyWeightContributionRow,
                footer: _contributionFooter(context, state),
                children: [
                  AppTextFieldRow(
                    key: const Key('FinalExerciseDetails.contribution'),
                    label: l10n.createExerciseContributionLabel,
                    initialValue: '${state.contribution ?? ''}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9-]')),
                    ],
                    onChanged: cubit.contributionChanged,
                    textCapitalization: TextCapitalization.none,
                    suffixText: '%',
                  ),
                  if (!state.isContributionInRange)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: AppInlineMessage(
                        kind: AppInlineMessageKind.error,
                        text: l10n.createExerciseContributionRange,
                        kindLabel: l10n.errorLabel,
                      ),
                    ),
                  if (state.hasBodyweightConflict)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: AppInlineMessage(
                        kind: AppInlineMessageKind.warning,
                        text: l10n.createExerciseBodyweightConflict,
                        kindLabel: l10n.warningLabel,
                      ),
                    ),
                ],
              ),
              AppSection(
                header:
                    '${l10n.createExerciseAlternateNames} · '
                    '${state.alternateNames.length}/'
                    '${ExerciseDefinitionRules.alternateNamesLimit}',
                footer: l10n.createExerciseAlternateNamesFooter,
                children: [
                  AppTextFieldRow(
                    key: const Key('FinalExerciseDetails.alternateNames'),
                    label: l10n.createExerciseAlternateNamesHint,
                    initialValue: state.alternateNames,
                    textCapitalization: TextCapitalization.words,
                    minLines: 1,
                    maxLines: 2,
                    onChanged: cubit.alternateNamesChanged,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ExerciseDefinitionRules.alternateNamesLimit,
                      ),
                    ],
                  ),
                ],
              ),
              AppSection(
                header: l10n.exerciseDescriptionRow,
                children: [
                  AppTextFieldRow(
                    key: const Key('FinalExerciseDetails.description'),
                    label: l10n.createExerciseDescriptionHint,
                    initialValue: state.draft.description,
                    minLines: 2,
                    maxLines: 6,
                    onChanged: cubit.descriptionChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('FinalExerciseDetails.next'),
              label: l10n.createExerciseNext,
              onPressed: switch (cubit.next) {
                final ExerciseDraft next => () => unawaited(
                  pushCreateStep(context, ExerciseSavePage(draft: next)),
                ),
                null => null,
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The weight the contribution moves at the profile's weight, in its
  /// unit; without a weight, what the figure means.
  static String _contributionFooter(
    BuildContext context,
    FinalExerciseDetailsState state,
  ) {
    final l10n = context.l10n;
    final profile = switch (context.read<AppBloc>().state) {
      AppAuthenticated(:final profile) => profile,
      _ => null,
    };
    final kilograms = profile?.submittedWeightKilograms;
    final contribution = state.contribution;
    if (kilograms == null || contribution == null) {
      return l10n.createExerciseContributionFooter;
    }
    return l10n.createExerciseContributionMoved(
      AppFormat.weight(
        kilograms * contribution / 100,
        WorkoutText.preferredWeightUnit(profile?.submittedWeightUnitPreference),
        maxFractionDigits: 0,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }
}

/// A 0–5 rating with buttons to step it (Swift `Stepper` over a
/// `RatingBar`), read out as "3 of 5".
class _RatingStepper extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExerciseRatingRow(
      title: title,
      rating: value,
      trailing: [
        AppIconButton(
          icon: AppSymbols.decrease,
          semanticLabel: '${l10n.editorDecrease}, $title',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        AppIconButton(
          icon: AppSymbols.increase,
          semanticLabel: '${l10n.editorIncrease}, $title',
          onPressed: value < 5 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
