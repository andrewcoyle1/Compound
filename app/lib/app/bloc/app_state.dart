part of 'app_bloc.dart';

sealed class AppState extends Equatable {
  const new();

  factory from(AuthUser? user) =>
      user == null ? const AppUnauthenticated() : AppAuthenticated(user);

  @override
  List<Object?> get props => [];
}

/// Whether the signed-in user's profile (`users/{uid}`) has been read.
enum AppProfileStatus {
  /// Waiting for it, or for a new account's profile to be written.
  loading,

  /// Read: [AppAuthenticated.profile] holds it.
  ready,

  /// It exists but can't be read, or there was no way to tell whether it
  /// exists (offline on a first launch). The app waits for a retry.
  failure,
}

final class AppAuthenticated extends AppState {
  const new(
    this.user, {
    this.profile,
    this.profileStatus = AppProfileStatus.loading,
  });

  final AuthUser user;

  /// The profile, once [profileStatus] is ready.
  final UserModel? profile;

  final AppProfileStatus profileStatus;

  /// Where onboarding resumes, or null once it is done or while the profile
  /// is unknown. As Swift's `WelcomePresenter`, a finished onboarding goes
  /// to the tabs even if a later step's data has gone.
  OnboardingStep? get onboardingStep => switch (profile) {
    null => null,
    final profile when profile.didCompleteOnboarding => null,
    final profile => inferredOnboardingStep(profile),
  };

  @override
  List<Object?> get props => [user, profile, profileStatus];
}

final class AppUnauthenticated extends AppState {
  const new();
}
