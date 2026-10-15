import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/health_disclaimer/health_disclaimer_cubit.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// The health disclaimer: its text, and a switch accepting each notice.
///
/// Swift adds a link to each document under its switch; those links are
/// still placeholders there (`LegalDocument.swift`), so they wait for the
/// published documents.
class HealthDisclaimerPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => HealthDisclaimerCubit(
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      ),
      child: const HealthDisclaimerView(),
    );
  }
}

class HealthDisclaimerView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<HealthDisclaimerCubit>();
    final state = context.watch<HealthDisclaimerCubit>().state;
    return BlocListener<HealthDisclaimerCubit, HealthDisclaimerState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) => switch (state.status) {
        HealthDisclaimerStatus.failure => showOnboardingFailure(
          context,
          title: l10n.onboardingUnableToSaveConsent,
        ),
        _ => null,
      },
      child: OnboardingQuestion(
        step: OnboardingStep.healthDisclaimer,
        title: l10n.onboardingDisclaimerTitle,
        isLoading: state.status == HealthDisclaimerStatus.saving,
        onContinue: state.canContinue ? cubit.accept : null,
        children: [
          AppSection(
            header: l10n.onboardingDisclaimerHeader,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Text(l10n.onboardingDisclaimerText),
              ),
            ],
          ),
          AppSection(
            children: [
              AppListRowToggle(
                title: l10n.onboardingAcceptDisclaimer,
                value: state.acceptedTerms,
                onChanged: (accepted) => cubit.termsChanged(accepted: accepted),
              ),
            ],
          ),
          AppSection(
            children: [
              AppListRowToggle(
                title: l10n.onboardingAcceptPrivacy,
                value: state.acceptedPrivacy,
                onChanged: (accepted) =>
                    cubit.privacyChanged(accepted: accepted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
