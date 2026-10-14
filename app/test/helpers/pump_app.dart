import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository;

class MockAppBloc extends Mock implements AppBloc;

class MockUserRepository extends Mock implements UserRepository;

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthRepository? authRepository,
    UserRepository? userRepository,
    AppBloc? appBloc,
  }) {
    return pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(
            value: authRepository ?? MockAuthRepository(),
          ),
          RepositoryProvider.value(
            value: userRepository ?? MockUserRepository(),
          ),
        ],
        child: BlocProvider.value(
          value: appBloc ?? MockAppBloc(),
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: widget,
          ),
        ),
      ),
    );
  }
}
