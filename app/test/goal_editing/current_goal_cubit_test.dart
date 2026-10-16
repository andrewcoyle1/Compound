import 'package:body_repository/body_repository.dart';
import 'package:compound/goal_editing/current_goal_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  group(CurrentGoalCubit, () {
    test("follows the goal the profile names, the uid's without one", () async {
      final body = InMemoryBodyRepository(
        goals: [sampleWeightGoal(uid: 'uid', now: now)],
      );
      final cubit = CurrentGoalCubit(bodyRepository: body, uid: 'uid');
      expect(cubit.state, isNull);
      await pumpEventQueue();
      expect(cubit.state?.objective, OverarchingObjective.loseWeight);

      await body.abandonGoal('uid', 'uid');
      await pumpEventQueue();
      expect(cubit.state?.status, GoalStatus.abandoned);
      await cubit.close();

      final none = CurrentGoalCubit(
        bodyRepository: body,
        uid: 'uid',
        currentGoalId: 'other',
      );
      await pumpEventQueue();
      expect(none.state, isNull);
      await none.close();
    });

    test('a goal that cannot be read is none', () async {
      final cubit = CurrentGoalCubit(bodyRepository: _Failing(), uid: 'uid');
      await pumpEventQueue();
      expect(cubit.state, isNull);
      await cubit.close();
    });
  });
}

class _Failing extends InMemoryBodyRepository {
  @override
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId}) =>
      Stream.error(Exception('offline'));
}
