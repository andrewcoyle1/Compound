part of 'app_bloc.dart';

sealed class AppEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

final class AppUserSubscriptionRequested extends AppEvent {
  const new();
}

final class AppSignOutPressed extends AppEvent {
  const new();
}
