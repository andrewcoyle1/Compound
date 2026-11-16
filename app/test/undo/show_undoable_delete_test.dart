import 'package:app_ui/app_ui.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:compound/undo/show_undoable_delete.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('showUndoableDelete', () {
    late PendingDeletes pending;
    late List<String> written;
    late List<AppHaptic> haptics;
    var failing = false;
    var undone = 0;

    setUp(() {
      pending = PendingDeletes();
      written = [];
      haptics = [];
      failing = false;
      undone = 0;
      AppHaptics.debugPlay = haptics.add;
    });

    tearDown(() {
      AppHaptics.debugPlay = null;
      return pending.close();
    });

    Future<void> delete(WidgetTester tester, {bool accessible = false}) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(accessibleNavigation: accessible),
            child: Builder(
              builder: (context) => AppTextButton(
                label: 'Delete',
                onPressed: () => showUndoableDelete(
                  context,
                  key: 'gyms/a',
                  message: 'Gym deleted',
                  failedMessage: 'Unable to Delete Gym',
                  commit: () async {
                    if (failing) throw StateError('refused');
                    written.add('gyms/a');
                  },
                  onUndo: () => undone++,
                ),
              ),
            ),
          ),
        ),
        pendingDeletes: pending,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('hides the item at once and offers Undo', (tester) async {
      await delete(tester);
      expect(pending.keys, {'gyms/a'});
      expect(find.text('Gym deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(haptics, [AppHaptic.success]);
      expect(written, isEmpty);
    });

    testWidgets('Undo brings it back and writes nothing', (tester) async {
      await delete(tester);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(pending.keys, isEmpty);
      expect(undone, 1);
      await tester.pump(undoWindow);
      expect(written, isEmpty);
    });

    testWidgets('writes the delete when the window closes', (tester) async {
      await delete(tester);
      await tester.pump(undoWindow);
      await tester.pumpAndSettle();
      expect(written, ['gyms/a']);
      expect(pending.keys, isEmpty);
      expect(find.text('Gym deleted'), findsNothing);
    });

    testWidgets('writes the delete when another snack bar replaces it', (
      tester,
    ) async {
      await delete(tester);
      tester
          .state<AppSnackBarScopeState>(find.byType(AppSnackBarScope))
          .show('Saved');
      await tester.pumpAndSettle();
      expect(written, ['gyms/a']);
    });

    testWidgets('a failed write brings it back and says so', (tester) async {
      failing = true;
      await delete(tester);
      await tester.pump(undoWindow);
      await tester.pumpAndSettle();
      expect(pending.keys, isEmpty);
      expect(find.text('Unable to Delete Gym'), findsOneWidget);
      expect(haptics, [AppHaptic.success, AppHaptic.error]);
    });

    testWidgets('stays until dismissed for a screen reader', (tester) async {
      await delete(tester, accessible: true);
      await tester.pump(undoWindow * 2);
      expect(find.text('Gym deleted'), findsOneWidget);
      expect(written, isEmpty);
    });
  });
}
