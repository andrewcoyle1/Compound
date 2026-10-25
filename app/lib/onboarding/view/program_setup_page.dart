import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/training/program_setup_cubit.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:compound/programs/programs.dart' show NameMesocyclePage;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Choosing a shipped program to start, the recommended one first.
class ProgramSetupPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ProgramSetupCubit(
        trainingSetupService: context.read<TrainingSetupService>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        profile: profile,
        programs: PrebuiltCatalogue.instance.mesocycles,
      ),
      child: const ProgramSetupView(),
    );
  }
}

class ProgramSetupView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ProgramSetupCubit>();
    final state = context.watch<ProgramSetupCubit>().state;
    final recommended = state.recommended;

    Widget row(Mesocycle program) => AppSelectableRow(
      tile: true,
      title: program.name,
      subtitle: l10n.onboardingProgramSummary(
        workoutsPerMicrocycle(program),
        program.numMicrocycles,
      ),
      selected: program.id == state.selectedId,
      onPressed: () {
        unawaited(AppHaptics.selection());
        cubit.programSelected(program);
      },
    );

    return BlocListener<ProgramSetupCubit, ProgramSetupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, current) {
        switch (current.status) {
          case ProgramSetupStatus.failure:
            unawaited(
              showOnboardingFailure(
                context,
                title: l10n.onboardingUnableToStart,
              ),
            );
          case ProgramSetupStatus.started:
            onboardingSaved();
          case ProgramSetupStatus.idle || ProgramSetupStatus.starting:
            break;
        }
      },
      child: OnboardingQuestion(
        step: OnboardingStep.mesocycleSetup,
        title: l10n.onboardingProgramTitle,
        subtitle: l10n.onboardingProgramSubtitle,
        continueLabel: l10n.onboardingStartProgram,
        isLoading:
            state.status == ProgramSetupStatus.starting ||
            state.status == ProgramSetupStatus.started,
        onContinue: state.selected == null ? null : cubit.start,
        secondaryLabel: l10n.onboardingBuildMyOwn,
        onSecondary: () {
          cubit.buildOwnPressed();
          unawaited(NameMesocyclePage.openInPlace(context));
        },
        children: [
          if (recommended != null)
            AppSection(
              header: l10n.onboardingRecommended,
              footer: l10n.onboardingRecommendedFooter,
              grouped: false,
              children: [row(recommended)],
            ),
          if (state.others.isNotEmpty)
            AppSection(
              header: recommended == null
                  ? l10n.onboardingPrograms
                  : l10n.onboardingMorePrograms,
              grouped: false,
              children: [for (final program in state.others) row(program)],
            ),
        ],
      ),
    );
  }
}
