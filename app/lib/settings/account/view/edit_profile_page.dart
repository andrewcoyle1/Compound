import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/view/onboarding_labels.dart';
import 'package:compound/settings/account/cubit/edit_profile_cubit.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Edit Profile (Swift `EditProfileView`), opened from the profile. Save
/// writes the profile section; the privacy switch writes as it flips; the
/// username row opens its own editor. The photo button picks a new profile
/// photo, which Save uploads.
class EditProfilePage extends StatelessWidget {
  const new({super.key});

  /// Under the profile: `/profile/edit`.
  static const path = 'edit';
  static const name = 'editProfile';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    return BlocProvider(
      create: (context) => EditProfileCubit(
        userRepository: context.read<UserRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        connectivity: context.read(),
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
        user: state is AppAuthenticated ? state.profile : null,
      )..appeared(),
      child: const EditProfileView(),
    );
  }
}

class EditProfileView extends StatefulWidget {
  const new({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final EditProfileCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<EditProfileCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<EditProfileCubit>().state;
    return BlocListener<EditProfileCubit, EditProfileState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case EditProfileStatus.saved:
            context.pop();
          case EditProfileStatus.saveFailure:
            unawaited(
              showAppDialog<void>(
                context: context,
                title: l10n.editProfileSaveFailedTitle,
                message: l10n.editProfileSaveFailedMessage,
                actions: [AppDialogAction(label: l10n.settingsOk)],
              ),
            );
          case EditProfileStatus.privacyFailure:
            showAppSnackBar(
              context,
              l10n.editProfilePrivacyFailed,
              style: AppSnackBarStyle.error,
            );
          case EditProfileStatus.editing || EditProfileStatus.saving:
            break;
        }
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton.close(
            semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {
              _cubit.cancelPressed();
              context.pop();
            },
          ),
          title: Text(l10n.editProfileTitle),
          actions: [
            // Swift's toolbar photo button (`photo.badge.plus`).
            AppToolbarButton(
              icon: state.pickedPhoto != null || state.profileImageUrl != null
                  ? AppSymbols.changePhoto
                  : AppSymbols.addPhoto,
              semanticLabel:
                  state.pickedPhoto != null || state.profileImageUrl != null
                  ? l10n.editProfileChangePhoto
                  : l10n.editProfileAddPhoto,
              onPressed: state.uid == null ? null : _cubit.photoPressed,
            ),
            AppToolbarButton.confirm(
              semanticLabel: l10n.logWeightSave,
              isSaving: state.status == EditProfileStatus.saving,
              onPressed: state.canSave ? _cubit.savePressed : null,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              _PhotoSection(state: state),
              const SizedBox(height: AppSpacing.xl),
              _ProfileSection(state: state),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.editProfilePrivacyHeader,
                footer: l10n.editProfilePrivacyFooter,
                children: [
                  AppListRowToggle(
                    title: l10n.editProfilePrivateProfile,
                    value: state.isPrivate,
                    onChanged: state.uid == null
                        ? null
                        : (value) => _cubit.privacyChanged(isPrivate: value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The profile photo (Swift `imageSection`): a newly picked one, else the
/// stored one, else the person glyph, with the button that picks one.
class _PhotoSection extends StatelessWidget {
  const new({required this.state});

  final EditProfileState state;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final picked = state.pickedPhoto;
    final stored = state.profileImageUrl;
    final placeholder = Icon(
      AppSymbols.profile,
      size: _size,
      color: scheme.onSurfaceVariant,
    );
    return Center(
      child: ClipOval(
        child: SizedBox.square(
          dimension: _size,
          child: picked != null
              ? Image.memory(
                  picked,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.editProfilePhoto,
                  errorBuilder: (_, _, _) => placeholder,
                )
              : stored != null
              ? StoredImage(
                  stored,
                  semanticLabel: l10n.editProfilePhoto,
                  placeholder: placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const new({required this.state});

  final EditProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<EditProfileCubit>();
    final dateOfBirth = state.dateOfBirth;
    // Live, so a handle chosen in its own editor shows on the way back.
    final username = context.select<AppBloc, String?>(
      (bloc) => switch (bloc.state) {
        AppAuthenticated(:final profile?) => profile.username,
        _ => state.username,
      },
    );
    return AppSection(
      header: l10n.editProfileProfileHeader,
      children: [
        AppListRowButton(
          title: l10n.profileUsername,
          onPressed: () => SocialNavigation.openUsername(context),
          accessory: AppListRowValue(
            username == null
                ? l10n.profileNotSet
                : l10n.profileUsernameHandle(username),
          ),
        ),
        AppTextFieldRow(
          initialValue: state.firstName,
          label: l10n.onboardingFirstName,
          onChanged: cubit.firstNameChanged,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
        ),
        AppTextFieldRow(
          initialValue: state.lastName,
          label: l10n.editProfileLastName,
          onChanged: cubit.lastNameChanged,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.familyName],
        ),
        AppListRowButton(
          title: l10n.onboardingDateOfBirth,
          accessory: AppListRowValue(
            dateOfBirth == null
                ? l10n.profileNotSet
                : AppFormat.date(
                    dateOfBirth.toLocal(),
                    locale: context.dateLocale,
                  ),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: dateOfBirth?.toLocal() ?? now,
              firstDate: DateTime(now.year - 120, now.month, now.day),
              lastDate: now,
              initialEntryMode: DatePickerEntryMode.calendarOnly,
            );
            if (picked != null) cubit.dateOfBirthChanged(picked);
          },
        ),
        _OptionRow<Gender>(
          title: l10n.editProfileSex,
          selected: state.gender,
          options: Gender.values,
          label: (gender) => gender.label(l10n),
          onSelected: cubit.genderChanged,
        ),
        AppNumberField(
          label: l10n.editProfileHeight,
          value: state.height,
          prompt: '0',
          // Unit symbols read the same in every language.
          unit: state.heightUnit == LengthUnitPreference.inches ? 'in' : 'cm',
          onChanged: cubit.heightChanged,
        ),
        _OptionRow<CardioFitnessLevel>(
          title: l10n.editProfileCardioExperience,
          selected: state.cardioFitnessLevel,
          options: CardioFitnessLevel.values,
          label: (level) => level.label(l10n),
          onSelected: cubit.cardioFitnessLevelChanged,
        ),
        _OptionRow<ExerciseFrequency>(
          title: l10n.editProfileExerciseFrequency,
          selected: state.exerciseFrequency,
          options: ExerciseFrequency.values,
          label: (frequency) => frequency.label(l10n),
          onSelected: cubit.exerciseFrequencyChanged,
        ),
        _OptionRow<ActivityLevel>(
          title: l10n.editProfileDailyActivity,
          selected: state.activityLevel,
          options: ActivityLevel.values,
          label: (level) => level.label(l10n),
          onSelected: cubit.activityLevelChanged,
        ),
      ],
    );
  }
}

/// A picker row: its value, and a sheet of the options with "Not specified"
/// first, as Swift's menu pickers offer.
class _OptionRow<T extends Object> extends StatelessWidget {
  const new({
    required this.title,
    required this.selected,
    required this.options,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final T? selected;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = this.selected;
    return AppListRowButton(
      title: title,
      accessory: AppListRowMenu(
        selected == null ? l10n.editProfileNotSpecified : label(selected),
      ),
      onPressed: () => showAppSheet<void>(
        context: context,
        builder: (sheetContext) {
          void choose(T? option) {
            onSelected(option);
            Navigator.of(sheetContext).pop();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.xl,
            ),
            child: AppSection(
              header: title,
              children: [
                AppSelectableRow(
                  title: l10n.editProfileNotSpecified,
                  selected: selected == null,
                  onPressed: () => choose(null),
                ),
                for (final option in options)
                  AppSelectableRow(
                    title: label(option),
                    selected: option == selected,
                    onPressed: () => choose(option),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on CardioFitnessLevel {
  String label(AppLocalizations l10n) => switch (this) {
    CardioFitnessLevel.beginner => l10n.editProfileCardioBeginner,
    CardioFitnessLevel.novice => l10n.editProfileCardioNovice,
    CardioFitnessLevel.intermediate => l10n.editProfileCardioIntermediate,
    CardioFitnessLevel.advanced => l10n.editProfileCardioAdvanced,
    CardioFitnessLevel.elite => l10n.editProfileCardioElite,
  };
}
