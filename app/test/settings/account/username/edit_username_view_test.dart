import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/account/username/edit_username_bloc.dart';
import 'package:compound/settings/account/username/edit_username_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/helpers.dart';

class _MockEditUsernameBloc
    extends MockBloc<EditUsernameEvent, EditUsernameState>
    implements EditUsernameBloc;

void main() {
  group(EditUsernameView, () {
    const viewer = UserModel(userId: 'me', username: 'old');
    const typed = EditUsernameState(
      text: 'alice',
      status: UsernameStatus.available,
    );
    late _MockEditUsernameBloc bloc;
    late StreamController<EditUsernameState> states;
    late List<AppHaptic> haptics;

    setUp(() {
      bloc = _MockEditUsernameBloc();
      states = StreamController();
      whenListen(bloc, states.stream, initialState: typed);
      haptics = [];
      AppHaptics.debugPlay = haptics.add;
    });

    tearDown(() {
      AppHaptics.debugPlay = null;
      unawaited(states.close());
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      BlocProvider<EditUsernameBloc>.value(
        value: bloc,
        child: const EditUsernameView(viewer: viewer),
      ),
      disableAnimations: false,
    );

    double fieldX(WidgetTester tester) =>
        tester.getTopLeft(find.byType(AppCard)).dx;

    testWidgets('shakes the field with an error haptic when the name was '
        'taken during the save', (tester) async {
      await pump(tester);
      final rest = fieldX(tester);
      states.add(typed.copyWith(isSaving: true));
      await tester.pump();
      states.add(typed.copyWith(status: UsernameStatus.taken));
      await tester.pump();
      await tester.pump();
      await tester.pump(AppShake.duration ~/ 12);
      expect(fieldX(tester), isNot(rest));
      expect(haptics, [AppHaptic.error]);
      await tester.pump(AppShake.duration);
      expect(fieldX(tester), rest);
    });

    testWidgets('a name found taken while typing does not shake', (
      tester,
    ) async {
      await pump(tester);
      final rest = fieldX(tester);
      states.add(typed.copyWith(status: UsernameStatus.taken));
      await tester.pump();
      await tester.pump(AppShake.duration ~/ 12);
      expect(fieldX(tester), rest);
      expect(haptics, isEmpty);
    });

    testWidgets('shakes the field when the save fails', (tester) async {
      await pump(tester);
      final rest = fieldX(tester);
      states.add(typed.copyWith(failureId: 1));
      await tester.pump();
      await tester.pump();
      await tester.pump(AppShake.duration ~/ 12);
      expect(fieldX(tester), isNot(rest));
      expect(haptics, [AppHaptic.heavy]);
    });
  });
}
