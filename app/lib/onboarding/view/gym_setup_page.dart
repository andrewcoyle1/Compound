import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/training/gym_setup_cubit.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:program_repository/program_repository.dart';

/// Naming the user's gym, which starts with the whole catalogue.
class GymSetupPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => GymSetupCubit(
        trainingSetupService: context.read<TrainingSetupService>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        profile: profile,
        untitledName: l10n.onboardingUntitledGym,
        kilogramStackName: l10n.onboardingKilogramStack,
      ),
      child: const GymSetupView(),
    );
  }
}

class GymSetupView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<GymSetupCubit>();
    final state = context.watch<GymSetupCubit>().state;
    return BlocListener<GymSetupCubit, GymSetupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, current) {
        switch (current.status) {
          case GymSetupStatus.failure:
            unawaited(
              showOnboardingFailure(
                context,
                title: l10n.onboardingUnableToSaveGym,
              ),
            );
          case GymSetupStatus.saved:
            onboardingSaved();
          case GymSetupStatus.idle || GymSetupStatus.saving:
            break;
        }
      },
      child: OnboardingQuestion(
        step: OnboardingStep.gymProfileSetup,
        title: l10n.onboardingGymTitle,
        isLoading:
            state.status == GymSetupStatus.saving ||
            state.status == GymSetupStatus.saved,
        onContinue: state.canSave ? cubit.save : null,
        children: [
          AppSection(
            header: l10n.onboardingGymHeader,
            footer: l10n.onboardingGymFooter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingGymName,
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: cubit.nameChanged,
                  onSubmitted: (_) => cubit.save(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
