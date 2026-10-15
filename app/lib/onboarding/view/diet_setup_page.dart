import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/diet/diet_setup_cubit.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/view/onboarding_labels.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The diet step: use the recommended plan or answer the diet,
/// distribution and protein questions, then review and save the plan,
/// which finishes onboarding.
class DietSetupPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) {
        final cubit = DietSetupCubit(
          nutritionRepository: context.read<NutritionRepository>(),
          programRepository: context.read<ProgramRepository>(),
          bodyRepository: context.read<BodyRepository>(),
          userRepository: context.read<UserRepository>(),
          analyticsRepository: context.read<AnalyticsRepository>(),
          profile: profile,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const DietSetupView(),
    );
  }
}

class DietSetupView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DietSetupCubit>();
    final state = context.watch<DietSetupCubit>().state;
    final onBack = state.question == DietQuestion.intro ? null : cubit.back;
    const step = OnboardingStep.customiseProgram;

    final question = state.status == DietSetupStatus.loading
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          )
        : switch (state.question) {
            DietQuestion.intro => OnboardingQuestion(
              step: step,
              title: l10n.onboardingDietIntroTitle,
              continueLabel: l10n.onboardingUseRecommendedPlan,
              onContinue: cubit.useRecommendedPlan,
              secondaryLabel: l10n.onboardingCustomize,
              onSecondary: cubit.customize,
              children: [
                AppSection(
                  header: l10n.onboardingDietProgram,
                  footer: l10n.onboardingDietIntroFooter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(l10n.onboardingDietIntroText),
                    ),
                  ],
                ),
              ],
            ),
            DietQuestion.preferredDiet => OnboardingQuestion(
              step: step,
              title: l10n.onboardingDietTitle,
              onBack: onBack,
              onContinue: cubit.dietContinued,
              children: [
                OnboardingOptions<maths.PreferredDiet>(
                  header: l10n.onboardingDietHeader,
                  options: maths.PreferredDiet.values,
                  selected: state.diet,
                  title: (diet) => diet.label(l10n),
                  subtitle: (diet) => diet.detail(l10n),
                  onSelected: cubit.dietSelected,
                ),
              ],
            ),
            DietQuestion.distribution => OnboardingQuestion(
              step: step,
              title: l10n.onboardingDistributionTitle,
              onBack: onBack,
              onContinue: state.distribution == null
                  ? null
                  : cubit.distributionContinued,
              children: [
                OnboardingOptions<maths.CalorieDistribution>(
                  header: l10n.onboardingDistributionHeader,
                  options: maths.CalorieDistribution.values,
                  selected: state.distribution,
                  title: (distribution) => distribution.label(l10n),
                  subtitle: (distribution) => distribution.detail(l10n),
                  onSelected: cubit.distributionSelected,
                ),
              ],
            ),
            DietQuestion.protein => OnboardingQuestion(
              step: step,
              title: l10n.onboardingProteinTitle,
              onBack: onBack,
              onContinue: cubit.proteinContinued,
              children: [
                OnboardingOptions<maths.ProteinIntake>(
                  header: l10n.onboardingProteinHeader,
                  footer: l10n.onboardingProteinFooter,
                  options: maths.ProteinIntake.values,
                  selected: state.protein,
                  title: (protein) => protein.label(l10n),
                  subtitle: (protein) => protein.detail(l10n),
                  onSelected: cubit.proteinSelected,
                ),
              ],
            ),
            DietQuestion.plan => OnboardingQuestion(
              step: step,
              title: l10n.onboardingPlanTitle,
              onBack: onBack,
              isLoading:
                  state.status == DietSetupStatus.saving ||
                  state.status == DietSetupStatus.saved,
              onContinue: cubit.save,
              children: _plan(context, state),
            ),
          };

    return BlocListener<DietSetupCubit, DietSetupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, current) {
        if (current.status == DietSetupStatus.saved) onboardingSaved();
        if (current.status == DietSetupStatus.failure) {
          unawaited(
            showOnboardingFailure(
              context,
              title: l10n.onboardingUnableToUpdate,
            ),
          );
        }
      },
      child: PopScope(
        canPop: onBack == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.back();
        },
        child: question,
      ),
    );
  }

  List<Widget> _plan(BuildContext context, DietSetupState state) {
    final l10n = context.l10n;
    final plan = state.plan;
    if (plan == null) return const [];
    final locale = Localizations.localeOf(context).toLanguageTag();
    String kcal(num value) => AppFormat.kcal(value, locale: locale);
    String grams(num value) => AppFormat.grams(value, locale: locale);
    final diet = maths.PreferredDiet.tryParse(plan.preferredDiet);
    final distribution = maths.CalorieDistribution.tryParse(
      plan.calorieDistribution,
    );
    final protein = maths.ProteinIntake.tryParse(plan.proteinIntake);
    final mesocycleName = state.mesocycleName;
    final days = state.trainingDaysPerWeek;
    final resting = state.restingKcalAboveTarget;
    return [
      AppSection(
        header: l10n.onboardingOverview,
        footer: l10n.onboardingPlanFooter,
        children: [
          if (mesocycleName != null && days != null)
            AppListRow(
              title: l10n.onboardingPlanMesocycle(mesocycleName, days),
            ),
          AppListRow(title: l10n.onboardingPlanTdee(plan.tdeeEstimate.round())),
          if (diet != null)
            AppListRow(title: l10n.onboardingPlanDiet(diet.label(l10n))),
          AppListRow(
            title: l10n.onboardingPlanFloor(
              kcal(
                maths.calorieFloor(maths.Gender.tryParse(state.gender?.value)),
              ),
            ),
          ),
          if (distribution != null)
            AppListRow(
              title: l10n.onboardingPlanDistribution(distribution.label(l10n)),
            ),
          if (protein != null)
            AppListRow(title: l10n.onboardingPlanProtein(protein.label(l10n))),
        ],
      ),
      if (resting != null)
        AppInlineMessage(
          kind: AppInlineMessageKind.warning,
          text: l10n.onboardingBelowResting(kcal(resting)),
          kindLabel: l10n.warningLabel,
        ),
      AppSection(
        header: l10n.onboardingSevenDayTargets,
        children: [
          for (final (index, day) in plan.days.indexed)
            AppListRow(
              title: l10n.onboardingPlanDay(index + 1),
              subtitle: l10n.onboardingPlanDayMacros(
                kcal(day.calories),
                grams(day.proteinGrams),
                grams(day.carbGrams),
                grams(day.fatGrams),
              ),
            ),
        ],
      ),
    ];
  }
}
