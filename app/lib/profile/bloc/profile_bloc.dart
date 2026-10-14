import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// The signed-in user's profile, following [UserRepository.watchUser].
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  new({required this._userRepository, required this._uid})
    : super(const ProfileLoading()) {
    on<ProfileSubscriptionRequested>(_onSubscriptionRequested);
  }

  final UserRepository _userRepository;
  final String _uid;

  Future<void> _onSubscriptionRequested(
    ProfileSubscriptionRequested event,
    Emitter<ProfileState> emit,
  ) => emit.forEach(
    _userRepository.watchUser(_uid),
    onData: (user) =>
        user == null ? const ProfileUnavailable() : ProfileLoaded(user),
    onError: (_, _) => const ProfileUnavailable(),
  );
}
