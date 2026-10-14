part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the profile.
final class ProfileSubscriptionRequested extends ProfileEvent {
  const new();
}
