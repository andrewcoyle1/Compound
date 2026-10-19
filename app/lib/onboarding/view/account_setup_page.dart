import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/integrations/view/health_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound/onboarding/logic/expenditure_estimate.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/view/onboarding_labels.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/widgets/number_wheel.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_repository/health_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:user_repository/user_repository.dart';

/// Account setup: name, sex, date of birth, height, weight, exercise
/// frequency, activity, then the expenditure estimate that saves them.
class AccountSetupPage extends StatelessWidget {
  const new({super.key});

  /// Countries that measure height in feet and inches, as Swift reads the
  /// locale's measurement system.
  static const _imperialCountries = {'US', 'LR', 'MM'};

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final country = PlatformDispatcher.instance.locale.countryCode;
    return BlocProvider(
      create: (context) => AccountSetupCubit(
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
        now: DateTime.now(),
        usesMetric: !_imperialCountries.contains(country),
        profile: state.profile,
        health: context.read<HealthRepository>(),
      ),
      child: const AccountSetupView(),
    );
  }
}

class AccountSetupView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountSetupCubit>();
    final state = context.watch<AccountSetupCubit>().state;
    final saving = state.status == AccountSetupStatus.saving;
    final onBack = state.question == AccountQuestion.name ? null : cubit.back;

    final question = switch (state.question) {
      AccountQuestion.name => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingNameTitle,
        subtitle: l10n.onboardingNameSubtitle,
        isLoading: saving,
        onContinue: state.canSaveName ? cubit.saveName : null,
        children: [
          _NamePhoto(state: state),
          const SizedBox(height: AppSpacing.l),
          _NameFields(state: state),
        ],
      ),
      AccountQuestion.gender => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingGenderTitle,
        subtitle: l10n.onboardingGenderSubtitle,
        onBack: onBack,
        onContinue: state.gender == null ? null : cubit.genderContinued,
        children: [
          if (isAppleHealth(context)) _HealthFill(state: state),
          OnboardingOptions<Gender>(
            options: Gender.values,
            selected: state.gender,
            title: (gender) => gender.label(l10n),
            subtitle: (gender) => gender == Gender.preferNotToSay
                ? l10n.genderPreferNotToSayDetail
                : null,
            onSelected: cubit.genderSelected,
          ),
        ],
      ),
      AccountQuestion.dateOfBirth => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingDateOfBirthTitle,
        subtitle: l10n.onboardingDateOfBirthSubtitle,
        onBack: onBack,
        onContinue: cubit.dateOfBirthContinued,
        children: [
          if (isAppleHealth(context)) _HealthFill(state: state),
          _DateOfBirthRow(date: state.dateOfBirth),
        ],
      ),
      AccountQuestion.height => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingHeightTitle,
        subtitle: l10n.onboardingHeightSubtitle,
        onBack: onBack,
        onContinue: cubit.heightContinued,
        children: [
          _HealthFill(state: state),
          _HeightPicker(state: state),
        ],
      ),
      AccountQuestion.weight => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingWeightTitle,
        subtitle: l10n.onboardingWeightSubtitle,
        onBack: onBack,
        onContinue: state.canSubmitWeight ? cubit.weightContinued : null,
        children: [
          _HealthFill(state: state),
          _WeightPicker(state: state),
        ],
      ),
      AccountQuestion.exerciseFrequency => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingFrequencyTitle,
        subtitle: l10n.onboardingFrequencySubtitle,
        onBack: onBack,
        onContinue: state.exerciseFrequency == null
            ? null
            : cubit.exerciseFrequencyContinued,
        children: [
          OnboardingOptions<ExerciseFrequency>(
            options: ExerciseFrequency.values,
            selected: state.exerciseFrequency,
            title: (frequency) => frequency.label(l10n),
            onSelected: cubit.exerciseFrequencySelected,
          ),
        ],
      ),
      AccountQuestion.activity => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingActivityTitle,
        subtitle: l10n.onboardingActivitySubtitle,
        onBack: onBack,
        onContinue: state.activityLevel == null
            ? null
            : cubit.activityContinued,
        children: [
          OnboardingOptions<ActivityLevel>(
            options: ActivityLevel.values,
            selected: state.activityLevel,
            title: (level) => level.label(l10n),
            subtitle: (level) => level.detail(l10n),
            onSelected: cubit.activitySelected,
          ),
        ],
      ),
      AccountQuestion.expenditure => OnboardingQuestion(
        step: OnboardingStep.completeAccountSetup,
        title: l10n.onboardingExpenditureTitle,
        onBack: onBack,
        isLoading: saving,
        onContinue: cubit.saveProfile,
        children: [
          if (state.answers case final answers?)
            ..._expenditure(
              context,
              expenditureBreakdown(answers, now: DateTime.now()),
            ),
        ],
      ),
    };

    return BlocListener<AccountSetupCubit, AccountSetupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) => switch (state.status) {
        AccountSetupStatus.nameFailure => showOnboardingFailure(
          context,
          title: l10n.onboardingUnableToSave,
        ),
        AccountSetupStatus.profileFailure => showOnboardingFailure(
          context,
          title: l10n.onboardingUnableToSaveProfile,
          onRetry: cubit.saveProfile,
        ),
        _ => null,
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

  List<Widget> _expenditure(
    BuildContext context,
    ExpenditureBreakdown figures,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String kcal(num value) => AppFormat.kcal(value, locale: locale);
    final multiplier = NumberFormat('0.00', locale);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final parts = [
      (l10n.onboardingRestingCalories, figures.restingKcal),
      (l10n.onboardingActivityCalories, figures.activityKcal),
      (l10n.onboardingDigestionCalories, figures.digestionKcal),
    ];
    return [
      MethodInfoHeader(
        title: l10n.onboardingExpenditureHeader,
        info: MethodInfo.formulaExpenditure(l10n),
      ),
      AppSection(
        footer: l10n.onboardingExpenditureFooter,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.s,
              children: [
                Text(
                  AppFormat.number(figures.totalKcal, locale: locale),
                  style: AppTextStyles.display,
                ),
                Text(
                  l10n.onboardingKcalPerDay,
                  style: AppTextStyles.sectionTitle.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
      MethodInfoHeader(
        title: l10n.onboardingBreakdown,
        info: MethodInfo.thermicEffectOfFood(l10n),
      ),
      AppSection(
        children: [
          for (final (name, value) in parts)
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name)),
                        Text(
                          kcal(value),
                          style: AppTextStyles.rowTitle.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                    ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: figures.totalKcal > 0
                            ? value / figures.totalKcal
                            : 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      MethodInfoHeader(
        title: l10n.onboardingHowCalculated,
        info: MethodInfo.restingMetabolicRate(l10n),
      ),
      AppSection(
        footer: l10n.onboardingHowCalculatedFooter,
        children: [
          AppListRow(
            title: l10n.onboardingRestingCalories,
            accessory: AppListRowValue(kcal(figures.restingKcal)),
          ),
          AppListRow(
            title: l10n.onboardingPhysicalActivityLevel,
            accessory: AppListRowValue(
              '× ${multiplier.format(figures.activityMultiplier)}',
            ),
          ),
          AppListRow(
            title: l10n.onboardingTotal,
            accessory: AppListRowValue(kcal(figures.totalKcal)),
          ),
        ],
      ),
    ];
  }
}

/// "Fill from Apple Health" over a question's control, and what it found
/// (Swift `AppleHealthFillSection`). Health Connect holds no date of birth
/// or sex, so Android offers it for height and weight only.
class _HealthFill extends StatelessWidget {
  const new({required this.state});

  final AccountSetupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fill = state.healthFill;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: AppSection(
        children: [
          AppListRowButton(
            title: l10n.healthFill(context),
            icon: AppSymbols.heart,
            accessory: fill == HealthFill.loading
                ? const AppListRowCustom(CircularProgressIndicator.adaptive())
                : null,
            onPressed: () => unawaited(
              context.read<AccountSetupCubit>().fillFromHealthPressed(),
            ),
          ),
          if (fill == HealthFill.filled || fill == HealthFill.notFound)
            AppInlineMessage(
              kind: AppInlineMessageKind.info,
              kindLabel: l10n.infoLabel,
              text: fill == HealthFill.filled
                  ? l10n.healthFilled(context)
                  : l10n.healthNotFound(context),
            ),
        ],
      ),
    );
  }
}

/// The optional profile photo (`NamePhotoView.imageSection`): the photo
/// picked or already set, or a glyph inviting one; Remove Photo; and a
/// message when a photo could not be read.
class _NamePhoto extends StatelessWidget {
  const new({required this.state});

  final AccountSetupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountSetupCubit>();
    final scheme = Theme.of(context).colorScheme;
    final side = MediaQuery.textScalerOf(context)
        .scale(AppIconSize.hero.points + AppSpacing.xl);
    final picked = state.photo;
    final stored = state.storedPhoto;
    final glyph = Icon(
      AppSymbols.profile,
      size: AppIconSize.hero.of(context),
      color: scheme.primary,
    );
    final invite = Column(
      spacing: AppSpacing.s,
      children: [
        glyph,
        Text(
          l10n.onboardingAddPhoto,
          style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    return Column(
      spacing: AppSpacing.s,
      children: [
        Semantics(
          button: true,
          label: state.hasPhoto
              ? l10n.onboardingChangePhoto
              : l10n.onboardingAddPhoto,
          excludeSemantics: true,
          child: InkWell(
            key: const Key('NamePhoto.photo'),
            customBorder: const CircleBorder(),
            onTap: () => unawaited(cubit.photoPressed()),
            child: picked != null || stored != null
                ? ClipOval(
                    child: SizedBox.square(
                      dimension: side,
                      child: picked != null
                          ? Image.memory(
                              picked,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => glyph,
                            )
                          : StoredImage(stored!, placeholder: glyph),
                    ),
                  )
                : invite,
          ),
        ),
        if (state.canRemovePhoto)
          AppTextButton(
            key: const Key('NamePhoto.remove'),
            label: l10n.onboardingRemovePhoto,
            onPressed: cubit.removePhoto,
            isDestructive: true,
          ),
        if (state.photoLoadFailed)
          AppInlineMessage(
            kind: AppInlineMessageKind.error,
            text: l10n.onboardingPhotoLoadFailed,
            kindLabel: l10n.errorLabel,
          ),
      ],
    );
  }
}

class _NameFields extends StatelessWidget {
  const new({required this.state});

  final AccountSetupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountSetupCubit>();
    return AppSection(
      header: l10n.onboardingNameHeader,
      footer: l10n.onboardingNameFooter,
      children: [
        AppTextFieldRow(
          label: l10n.onboardingFirstName,
          initialValue: state.firstName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          onChanged: cubit.firstNameChanged,
        ),
        AppTextFieldRow(
          label: l10n.onboardingLastName,
          initialValue: state.lastName,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.familyName],
          textInputAction: TextInputAction.done,
          onChanged: cubit.lastNameChanged,
          onSubmitted: (_) => cubit.saveName(),
        ),
      ],
    );
  }
}

class _DateOfBirthRow extends StatelessWidget {
  const new({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSection(
      children: [
        AppListRowButton(
          title: l10n.onboardingDateOfBirth,
          accessory: AppListRowValue(
            AppFormat.date(date, locale: context.dateLocale),
          ),
          onPressed: () async {
            final cubit = context.read<AccountSetupCubit>();
            final now = DateTime.now();
            // Nobody was born tomorrow; the far end reaches back a century
            // and more (`DateOfBirthPresenter.dateRange`).
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(now.year - 120, now.month, now.day),
              lastDate: now,
              initialEntryMode: DatePickerEntryMode.calendarOnly,
            );
            if (picked != null) cubit.dateOfBirthChanged(picked);
          },
        ),
      ],
    );
  }
}

/// Metric or imperial, as one segmented control.
class _UnitSwitch<T> extends StatelessWidget {
  const new({
    required this.metric,
    required this.imperial,
    required this.selected,
    required this.onChanged,
  });

  final T metric;
  final T imperial;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.onboardingUnits,
      container: true,
      child: AppSegmentedControl<T>(
        segments: [
          AppSegment(value: metric, label: l10n.onboardingMetric),
          AppSegment(value: imperial, label: l10n.onboardingImperial),
        ],
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }
}

/// About five rows of wheel, growing with the text so none is clipped.
class _Wheels extends StatelessWidget {
  const new({required this.header, required this.children, super.key});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppSection(
    header: header,
    children: [
      SizedBox(
        height: MediaQuery.textScalerOf(context).scale(150),
        child: Row(
          children: [for (final child in children) Expanded(child: child)],
        ),
      ),
    ],
  );
}

List<int> _range(int min, int max) => [for (var v = min; v <= max; v++) v];

class _HeightPicker extends StatelessWidget {
  const new({required this.state});

  final AccountSetupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountSetupCubit>();
    final metric = state.lengthUnit == LengthUnitPreference.centimeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xl,
      children: [
        _UnitSwitch(
          metric: LengthUnitPreference.centimeters,
          imperial: LengthUnitPreference.inches,
          selected: state.lengthUnit,
          onChanged: cubit.lengthUnitChanged,
        ),
        if (metric)
          _Wheels(
            key: const ValueKey('metric'),
            header: l10n.onboardingMetric,
            children: [
              NumberWheel(
                label: l10n.unitCentimeters,
                values: _range(centimetresRange.min, centimetresRange.max),
                selected: state.centimetres,
                itemLabel: l10n.onboardingCentimetres,
                onChanged: cubit.centimetresChanged,
              ),
            ],
          )
        else
          _Wheels(
            key: const ValueKey('imperial'),
            header: l10n.onboardingImperial,
            children: [
              NumberWheel(
                label: l10n.onboardingFeetLabel,
                values: _range(3, 8),
                selected: state.feet,
                itemLabel: l10n.onboardingFeet,
                onChanged: cubit.feetChanged,
              ),
              NumberWheel(
                label: l10n.unitInches,
                values: _range(0, 11),
                selected: state.inches,
                itemLabel: l10n.onboardingInches,
                onChanged: cubit.inchesChanged,
              ),
            ],
          ),
      ],
    );
  }
}

class _WeightPicker extends StatelessWidget {
  const new({required this.state});

  final AccountSetupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountSetupCubit>();
    final metric = state.weightUnit == WeightUnitPreference.kilograms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xl,
      children: [
        _UnitSwitch(
          metric: WeightUnitPreference.kilograms,
          imperial: WeightUnitPreference.pounds,
          selected: state.weightUnit,
          onChanged: cubit.weightUnitChanged,
        ),
        if (metric)
          _Wheels(
            key: const ValueKey('kilograms'),
            header: l10n.onboardingMetric,
            children: [
              NumberWheel(
                label: l10n.unitKilograms,
                values: _range(kilogramsRange.min, kilogramsRange.max),
                selected: state.kilograms,
                itemLabel: l10n.onboardingKilogramsValue,
                onChanged: cubit.kilogramsChanged,
              ),
            ],
          )
        else
          _Wheels(
            key: const ValueKey('pounds'),
            header: l10n.onboardingImperial,
            children: [
              NumberWheel(
                label: l10n.unitPounds,
                values: _range(poundsRange.min, poundsRange.max),
                selected: state.pounds,
                itemLabel: l10n.onboardingPoundsValue,
                onChanged: cubit.poundsChanged,
              ),
            ],
          ),
      ],
    );
  }
}
