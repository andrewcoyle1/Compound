import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/account/cubit/delete_account_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockUserRepository extends Mock implements UserRepository;

void main() {
  late AnalyticsRepository analytics;
  late AuthRepository auth;
  late UserRepository users;
  late List<(String, LogType)> events;
  late int deletedCallbacks;

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));

  setUp(() {
    analytics = _MockAnalyticsRepository();
    auth = _MockAuthRepository();
    users = _MockUserRepository();
    events = [];
    deletedCallbacks = 0;
    void record(Invocation invocation) {
      final event = invocation.positionalArguments.single as LoggableEvent;
      events.add((event.eventName, event.type));
    }

    when(() => analytics.trackEvent(any())).thenAnswer(record);
    when(() => analytics.trackScreenView(any())).thenAnswer(record);
    when(() => users.deleteUser(any())).thenAnswer((_) async {});
    // As the repositories do: sign in again, run the step, then delete.
    when(
      () => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')),
    ).thenAnswer((invocation) async {
      final beforeDelete =
          invocation.namedArguments[#beforeDelete] as Future<void> Function();
      await beforeDelete();
    });
  });

  DeleteAccountCubit build() => DeleteAccountCubit(
    authRepository: auth,
    userRepository: users,
    analytics: analytics,
    uid: 'user-1',
  );

  Future<void> delete(DeleteAccountCubit cubit) =>
      cubit.deletePressed(onDeleted: () => deletedCallbacks++);

  test('opening the screen deletes nothing', () {
    final cubit = build()
      ..appeared()
      ..disappeared();
    expect(cubit.state, DeleteAccountStatus.idle);
    verifyZeroInteractions(auth);
    verifyZeroInteractions(users);
    expect(events, [
      ('DeleteAccountView_Appear', LogType.analytic),
      ('DeleteAccountView_Disappear', LogType.analytic),
    ]);
  });

  blocTest<DeleteAccountCubit, DeleteAccountStatus>(
    'confirming deletes the profile inside the account deletion and says so',
    build: build,
    act: delete,
    expect: () => [DeleteAccountStatus.deleting, DeleteAccountStatus.deleted],
    verify: (_) {
      verify(() => users.deleteUser('user-1')).called(1);
      expect(deletedCallbacks, 1);
      expect(events, [
        ('Settings_DeleteAccount_StartConfirm', LogType.analytic),
        ('Settings_DeleteAccount_Success', LogType.analytic),
      ]);
    },
  );

  blocTest<DeleteAccountCubit, DeleteAccountStatus>(
    'cancelling the sign-in keeps the account without an error',
    setUp: () =>
        when(() => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')))
            .thenThrow(const SignInCancelled()),
    build: build,
    act: delete,
    expect: () => [DeleteAccountStatus.deleting, DeleteAccountStatus.idle],
    verify: (_) {
      verifyNever(() => users.deleteUser(any()));
      expect(deletedCallbacks, 0);
      expect(events.last, (
        'Settings_DeleteAccount_Cancelled',
        LogType.analytic,
      ));
    },
  );

  blocTest<DeleteAccountCubit, DeleteAccountStatus>(
    'a failed deletion leaves the person in their account',
    setUp: () =>
        when(() => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')))
            .thenThrow(const AuthFailure('network')),
    build: build,
    act: delete,
    expect: () => [DeleteAccountStatus.deleting, DeleteAccountStatus.failure],
    verify: (_) {
      expect(deletedCallbacks, 0);
      expect(events.last, ('Settings_DeleteAccount_Fail', LogType.severe));
    },
  );

  blocTest<DeleteAccountCubit, DeleteAccountStatus>(
    'a profile that cannot be deleted keeps the account',
    setUp: () =>
        when(() => users.deleteUser(any())).thenThrow(Exception('offline')),
    build: build,
    act: delete,
    expect: () => [DeleteAccountStatus.deleting, DeleteAccountStatus.failure],
  );

  blocTest<DeleteAccountCubit, DeleteAccountStatus>(
    'a second press while deleting, or once deleted, does nothing',
    build: build,
    seed: () => DeleteAccountStatus.deleting,
    act: (cubit) async {
      await delete(cubit);
      cubit.emit(DeleteAccountStatus.deleted);
      await delete(cubit);
    },
    expect: () => [DeleteAccountStatus.deleted],
    verify: (_) => verifyZeroInteractions(auth),
  );

  test('the screen closing mid-deletion still announces it', () async {
    final cubit = build();
    when(() => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')))
        .thenAnswer((_) => cubit.close());

    await delete(cubit);

    expect(deletedCallbacks, 1);
    expect(cubit.state, DeleteAccountStatus.deleting);
  });
}
