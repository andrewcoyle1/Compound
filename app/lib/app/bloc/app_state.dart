part of 'app_bloc.dart';

sealed class AppState extends Equatable {
  const new();

  factory from(AuthUser? user) =>
      user == null ? const AppUnauthenticated() : AppAuthenticated(user);

  @override
  List<Object> get props => [];
}

final class const AppAuthenticated(final AuthUser user) extends AppState {
  @override
  List<Object> get props => [user];
}

final class AppUnauthenticated extends AppState {
  const new();
}
