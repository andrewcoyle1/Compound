import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockSignInCubit extends MockCubit<SignInStatus> implements SignInCubit;

void main() {
  group(SignInPage, () {
    testWidgets('provides a SignInCubit', (tester) async {
      await tester.pumpApp(const SignInPage());
      expect(find.byType(SignInView), findsOneWidget);
    });
  });

  group(SignInView, () {
    late SignInCubit cubit;

    setUp(() {
      cubit = _MockSignInCubit();
      when(() => cubit.state).thenReturn(SignInStatus.idle);
      when(cubit.signInWithApple).thenAnswer((_) async {});
      when(cubit.signInWithGoogle).thenAnswer((_) async {});
      when(cubit.signInAnonymously).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      BlocProvider.value(value: cubit, child: const SignInView()),
    );

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('offers Apple, Google and no account on ${platform.name}', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        await pump(tester);
        expect(find.byType(AppSignInWithAppleButton), findsOneWidget);
        expect(find.byType(AppSignInWithGoogleButton), findsOneWidget);
        await tester.tap(find.text('Continue with Apple'));
        verify(cubit.signInWithApple).called(1);
        await tester.tap(find.text('Continue with Google'));
        verify(cubit.signInWithGoogle).called(1);
        await tester.tap(find.text('Continue without an account'));
        verify(cubit.signInAnonymously).called(1);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('disables the buttons while signing in', (tester) async {
      when(() => cubit.state).thenReturn(SignInStatus.inProgress);
      await pump(tester);
      await tester.tap(find.text('Continue with Google'));
      verifyNever(cubit.signInWithGoogle);
    });

    testWidgets('shows a snack bar when signing in fails', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable([SignInStatus.inProgress, SignInStatus.failure]),
        initialState: SignInStatus.idle,
      );
      await pump(tester);
      await tester.pump();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
