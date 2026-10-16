import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/training/gym_setup_cubit.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        analyticsRepository: context.read<AnalyticsRepository>(),
        profile: profile,
        kilogramStackName: l10n.onboardingKilogramStack,
      ),
      child: const GymSetupView(),
    );
  }
}

/// The name, then Continue opens the new gym's equipment
/// ([GymProfilePage]), whose own Continue saves the gym and makes it the
/// usual one, which moves onboarding on.
class GymSetupView extends StatelessWidget {
  const new({super.key});

  void _continue(BuildContext context) {
    final draft = context.read<GymSetupCubit>().draft();
    if (draft == null) return;
    unawaited(GymProfilePage.push(context, draft, continues: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<GymSetupCubit>();
    final state = context.watch<GymSetupCubit>().state;
    return OnboardingQuestion(
      step: OnboardingStep.gymProfileSetup,
      title: l10n.onboardingGymTitle,
      onContinue: state.canSave ? () => _continue(context) : null,
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
                onSubmitted: (_) => _continue(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
