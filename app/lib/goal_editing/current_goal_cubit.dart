import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';

/// The user's current weight goal, whatever its status (Swift
/// `currentGoal`), for Settings' Weight Goal row: the goal named by the
/// profile's `currentGoalId`, the uid's without one. Null when there is
/// none or it cannot be read.
class CurrentGoalCubit extends Cubit<WeightGoal?> {
  new({
    required BodyRepository bodyRepository,
    required String uid,
    String? currentGoalId,
  }) : super(null) {
    _subscription = bodyRepository
        .watchCurrentGoal(uid, currentGoalId: currentGoalId)
        .listen(emit, onError: (Object _) => emit(null));
  }

  late final StreamSubscription<WeightGoal?> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
