part of 'app_bloc.dart';

sealed class AppEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

final class AppUserSubscriptionRequested extends AppEvent {
  const new();
}

final class AppSignOutPressed extends AppEvent {
  const new();
}

/// Reads the profile again after it failed to load.
final class AppProfileRetryRequested extends AppEvent {
  const new();
}

/// The signed-in user's profile document changed: null when there is none
/// or it cannot be read.
final class _AppProfileChanged extends AppEvent {
  const new(this.user, this.profile);

  final AuthUser user;
  final UserModel? profile;

  @override
  List<Object?> get props => [user, profile];
}

final class _AppProfileFailed extends AppEvent {
  const new(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// The store said something new about the signed-in user's entitlements.
final class _AppPurchasesChanged extends AppEvent {
  const new(this.state);

  final PurchasesState state;

  @override
  List<Object?> get props => [state];
}
