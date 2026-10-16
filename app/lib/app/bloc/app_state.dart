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
    this.isPremium = true,
    this.signedInThisRun = false,
  });

  final AuthUser user;

  /// The profile, once [profileStatus] is ready.
  final UserModel? profile;

  final AppProfileStatus profileStatus;

  /// Whether the user is treated as a subscriber (`PremiumAccess.isPremium`):
  /// optimistic until the store has answered for them.
  final bool isPremium;

  /// Whether they signed in during this run of the app, rather than being
  /// signed in when it started. Fixed for as long as [user] is, so it is
  /// left out of equality.
  final bool signedInThisRun;

  /// Where onboarding resumes, or null once it is done or while the profile
  /// is unknown. As Swift's `WelcomePresenter`, a finished onboarding goes
  /// to the tabs even if a later step's data has gone.
  OnboardingStep? get onboardingStep => switch (profile) {
    null => null,
    final profile when profile.didCompleteOnboarding => null,
    final profile => inferredOnboardingStep(profile),
  };

  /// Whether the router holds the user at Subscription ("Why Subscribe?"):
  /// not premium, and either just signed in (Swift's `AuthPresenter` checks
  /// premium before anything else) or still in onboarding. Someone who had
  /// finished onboarding and was already signed in at launch reaches the
  /// tabs, as Swift's launch into the tab bar does; there the coach and
  /// Settings offer the paywall.
  bool get needsSubscription =>
      !isPremium && (signedInThisRun || onboardingStep != null);

  @override
  List<Object?> get props => [user, profile, profileStatus, isPremium];
}

final class AppUnauthenticated extends AppState {
  const new();
}
