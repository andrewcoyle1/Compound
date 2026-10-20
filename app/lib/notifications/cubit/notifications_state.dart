part of 'notifications_cubit.dart';

/// The last link to route: [linkId] counts them, so the same destination
/// twice is routed twice.
final class const NotificationsState({
  final DeepLink? link,
  final int linkId = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [link, linkId];
}
