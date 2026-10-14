part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Waiting for the first read.
final class ProfileLoading extends ProfileState {
  const new();
}

/// The profile document.
final class const ProfileLoaded(final UserModel user) extends ProfileState {
  @override
  List<Object> get props => [user];
}

/// There is no profile document, or it could not be read.
final class ProfileUnavailable extends ProfileState {
  const new();
}
